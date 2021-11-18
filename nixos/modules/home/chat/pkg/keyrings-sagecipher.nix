{ lib
, buildPythonPackage
, fetchFromGitHub
, openssh
, fetchpatch
, setuptools
, argon2_cffi
, keyring
, keyrings-alt
, paramiko
, pyinotify
, pycryptodome
, pytestCheckHook
, pytest
, pytest-runner
, pythonOlder
, click
}:

buildPythonPackage rec {
  pname = "keyrings.sagecipher";
  version = "0.7.5";
  disabled = pythonOlder "3.5";

  src = fetchFromGitHub {
    owner = "p-sherratt";
    repo = "sagecipher";
    rev = "60a5064c39512058552c84e5ae9b5946f1bb7afe";
    sha256 = "0ab4a7vgjjx7p3vqxw9a55j7w0cyxxiq86dmkxswqbg1l6naamnr";
  };

  patches = [
    # # upstream setup.cfg has an option that is not supported
    # ./fix-testsuite.patch
    # # change of API in keyrings.testing
    # (fetchpatch {
    #   url = "https://github.com/frispete/keyrings.cryptfile/commit/6fb9e45f559b8b69f7a0a519c0bece6324471d79.patch";
    #   sha256 = "sha256-1878pMO9Ed1zs1pl+7gMjwx77HbDHdE1CryN8TPfPdU=";
    # })
  ];

  nativeBuildInputs = [
    pytest-runner
  ];

  propagatedBuildInputs = [
    pytest-runner
    argon2_cffi
    keyring
    paramiko
    pycryptodome
    keyrings-alt
    pyinotify
    click
    setuptools
  ];

  pythonImportsCheck = [
    "sagecipher.cipher"
  ];

  checkInputs = [
    # pytestCheckHook
    pytest
    openssh
  ];

  checkPhase = ''
    HOME=$TMP pytest
  '';

  meta = with lib; {
    description = "Encrypted file keyring backend";
    homepage = "https://github.com/p-sherratt/sagecipher";
    license = licenses.asl20;
  };
}
