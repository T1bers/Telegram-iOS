import json
import os
import sys
import shutil
import tempfile
import plistlib
import argparse
import subprocess
import base64
import datetime
import shlex

from BuildEnvironment import run_executable_with_output, check_run_system


def setup_temp_keychain(p12_path, p12_password=''):
    """Create a temporary keychain and import the p12 certificate."""
    keychain_name = 'generate-profiles-temp.keychain'
    keychain_password = 'temp123'

    run_executable_with_output(
        'security',
        arguments=['delete-keychain', keychain_name],
        check_result=False
    )

    run_executable_with_output(
        'security',
        arguments=[
            'create-keychain', '-p', keychain_password, keychain_name
        ],
        check_result=True
    )

    # Preserve existing keychains in the search list
    existing = run_executable_with_output(
        'security',
        arguments=['list-keychains', '-d', 'user']
    )

    existing_keychains = shlex.split(existing)

    run_executable_with_output(
        'security',
        arguments=[
            'list-keychains', '-d', 'user', '-s', keychain_name
        ] + existing_keychains,
        check_result=True
    )

    run_executable_with_output(
        'security',
        arguments=['set-keychain-settings', keychain_name],
        check_result=True
    )

    run_executable_with_output(
        'security',
        arguments=['unlock-keychain', '-p', keychain_password, keychain_name],
        check_result=True
    )

    run_executable_with_output(
        'security',
        arguments=[
            'import', p12_path,
            '-k', keychain_name,
            '-P', p12_password,
            '-T', '/usr/bin/codesign',
            '-T', '/usr/bin/security'
        ],
        check_result=True
    )

    run_executable_with_output(
        'security',
        arguments=[
            'set-key-partition-list',
            '-S', 'apple-tool:,apple:',
            '-k', keychain_password,
            keychain_name
        ],
        check_result=True
    )

    return keychain_name


def cleanup_temp_keychain(keychain_name):
    """Remove the temporary keychain."""
    run_executable_with_output(
        'security',
        arguments=['delete-keychain', keychain_name],
        check_result=False
    )


def get_signing_identity_from_p12(p12_path, p12_password=''):
    """Extract the common name from the P12 certificate."""
    proc = subprocess.Popen(
        [
            'openssl', 'pkcs12',
            '-in', p12_path,
            '-passin', 'pass:' + p12_password,
            '-nokeys', '-legacy'
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    cert_pem, _ = proc.communicate()

    if proc.returncode != 0:
        return None

    proc2 = subprocess.Popen(
        [
            'openssl', 'x509',
            '-noout', '-subject',
            '-nameopt', 'oneline,-esc_msb'
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    subject, _ = proc2.communicate(cert_pem)

    if proc2.returncode != 0:
        return None

    subject = subject.decode('utf-8').strip()

    if 'CN = ' in subject:
        return subject.split('CN = ')[-1].split(',')[0].strip()

    return None


def get_certificate_base64_from_p12(p12_path, p12_password=''):
    """Extract certificate DER data from P12."""
    proc = subprocess.Popen(
        [
            'openssl', 'pkcs12',
            '-in', p12_path,
            '-passin', 'pass:' + p12_password,
            '-nokeys', '-legacy'
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    cert_pem, _ = proc.communicate()

    if proc.returncode != 0:
        raise RuntimeError('Could not extract certificate from P12')

    proc2 = subprocess.Popen(
        ['openssl', 'x509', '-outform', 'DER'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    cert_der, _ = proc2.communicate(cert_pem)

    if proc2.returncode != 0:
        raise RuntimeError('Could not convert certificate to DER')

    return base64.b64encode(cert_der).decode('utf-8')


def process_provisioning_profile(
    source,
    destination,
    certificate_data,
    signing_identity,
    keychain_name
):
    parsed_plist = run_executable_with_output(
        'security',
        arguments=['cms', '-D', '-i', source],
        check_result=True
    )

    profile = plistlib.loads(parsed_plist.encode('utf-8'))

    # Replace the profile certificate with the P12 certificate
    profile['DeveloperCertificates'] = [
        base64.b64decode(certificate_data)
    ]

    profile['ExpirationDate'] = (
        datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
        + datetime.timedelta(days=3650)
    )

    profile.pop('DER-Encoded-Profile', None)

    parsed_plist_file = tempfile.mktemp()

    try:
        with open(parsed_plist_file, 'wb') as file:
            plistlib.dump(profile, file)

        # Sign the modified provisioning profile
        run_executable_with_output(
            'security',
            arguments=[
                'cms',
                '-S',
                '-k', keychain_name,
                '-N', signing_identity,
                '-i', parsed_plist_file,
                '-o', destination
            ],
            check_result=True
        )
    finally:
        if os.path.exists(parsed_plist_file):
            os.unlink(parsed_plist_file)


def generate_provisioning_profiles(
    source_path,
    destination_path,
    certs_path
):
    p12_path = os.path.join(certs_path, 'SelfSigned.p12')

    if not os.path.exists(p12_path):
        print('{} does not exist'.format(p12_path))
        sys.exit(1)

    if not os.path.isdir(source_path):
        print('{} does not exist'.format(source_path))
        sys.exit(1)

    os.makedirs(destination_path, exist_ok=True)

    p12_password = ''

    try:
        certificate_data = get_certificate_base64_from_p12(
            p12_path,
            p12_password
        )

        signing_identity = get_signing_identity_from_p12(
            p12_path,
            p12_password
        )

    except Exception as error:
        print('Certificate extraction failed: {}'.format(error))
        sys.exit(1)

    if not signing_identity:
        print('Could not extract signing identity from {}'.format(p12_path))
        sys.exit(1)

    print('Using signing identity: {}'.format(signing_identity))

    keychain_name = setup_temp_keychain(
        p12_path,
        p12_password
    )

    try:
        processed = 0

        for file_name in os.listdir(source_path):
            if not file_name.endswith('.mobileprovision'):
                continue

            print('Processing {}'.format(file_name))

            process_provisioning_profile(
                source=os.path.join(source_path, file_name),
                destination=os.path.join(destination_path, file_name),
                certificate_data=certificate_data,
                signing_identity=signing_identity,
                keychain_name=keychain_name
            )

            processed += 1

        if processed == 0:
            raise RuntimeError('No provisioning profiles were found')

        print('Successfully generated {} profiles.'.format(processed))

    finally:
        cleanup_temp_keychain(keychain_name)
