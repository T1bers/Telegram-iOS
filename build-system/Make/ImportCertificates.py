import os
import sys
import argparse
import shlex

from BuildEnvironment import run_executable_with_output


def import_certificates(certificatesPath):
    if not os.path.isdir(certificatesPath):
        print('{} does not exist'.format(certificatesPath))
        sys.exit(1)

    keychain_name = 'temp.keychain'
    keychain_password = 'secret'

    run_executable_with_output(
        'security',
        arguments=['delete-keychain', keychain_name],
        check_result=False
    )

    run_executable_with_output(
        'security',
        arguments=['create-keychain', '-p', keychain_password, keychain_name],
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

    # Preserve existing macOS keychains.
    existing = run_executable_with_output(
        'security',
        arguments=['list-keychains', '-d', 'user']
    )
    existing_keychains = shlex.split(existing)

    search_keychains = [keychain_name]
    for keychain in existing_keychains:
        if keychain not in search_keychains:
            search_keychains.append(keychain)

    run_executable_with_output(
        'security',
        arguments=['list-keychains', '-d', 'user', '-s'] + search_keychains,
        check_result=True
    )

    imported_p12 = False

    for file_name in os.listdir(certificatesPath):
        file_path = os.path.join(certificatesPath, file_name)

        if file_name.lower().endswith('.p12'):
            print('Importing certificate: {}'.format(file_name))

            run_executable_with_output(
                'security',
                arguments=[
                    'import',
                    file_path,
                    '-k',
                    keychain_name,
                    '-P',
                    '',
                    '-T',
                    '/usr/bin/codesign',
                    '-T',
                    '/usr/bin/security'
                ],
                check_result=True
            )
            imported_p12 = True

    if not imported_p12:
        print('ERROR: No .p12 identity file found')
        sys.exit(1)

    wwdr_certificate = 'build-system/AppleWWDRCAG3.cer'

    if not os.path.isfile(wwdr_certificate):
        print('ERROR: {} does not exist'.format(wwdr_certificate))
        sys.exit(1)

    run_executable_with_output(
        'security',
        arguments=[
            'import',
            wwdr_certificate,
            '-k',
            keychain_name,
            '-T',
            '/usr/bin/codesign',
            '-T',
            '/usr/bin/security'
        ],
        check_result=True
    )

    run_executable_with_output(
        'security',
        arguments=[
            'set-key-partition-list',
            '-S',
            'apple-tool:,apple:',
            '-k',
            keychain_password,
            keychain_name
        ],
        check_result=True
    )

    print('===== CODE SIGNING IDENTITIES AFTER IMPORT =====')

    identity_output = run_executable_with_output(
        'security',
        arguments=['find-identity', '-v', '-p', 'codesigning'],
        check_result=True
    )

    print(identity_output)
    print('Certificates imported successfully.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='build')
    parser.add_argument('--path', required=True)

    args = parser.parse_args()
    import_certificates(args.path)
