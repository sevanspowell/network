{ lib
, buildPythonApplication
, fetchFromGitHub
, fetchpatch
, fetchurl
, terminaltables
, colorclass
, requests
, pyyaml
, setuptools
}:

let

  spec = fetchurl {
    url = "https://raw.githubusercontent.com/linode/linode-api-docs/v4.111.0/openapi.yaml";
    sha256 = "0j1i4ig1gwvwg2vfydpkh5skdirmbbfqbrznaq6v7sz35bk7carl";
  };

in

buildPythonApplication rec {
  pname = "linode-cli";
  version = "5.13.2";

  src = fetchFromGitHub {
    owner = "linode";
    repo = pname;
    rev = version;
    sha256 = "10mlkkprky7qqjrkv43v1lzmlgdjpkzy3729k9xxdm5mpq5bjdwj";
  };

  # remove need for git history
  prePatch = ''
    substituteInPlace setup.py \
      --replace "version=get_version()," "version='${version}',"
  '';

  propagatedBuildInputs = [
    terminaltables
    colorclass
    requests
    pyyaml
    setuptools
  ];

  postConfigure = ''
    python3 -m linodecli bake ${spec} --skip-config
    cp data-3 linodecli/
  '';

  # requires linode access token for unit tests, and running executable
  doCheck = false;

  meta = with lib; {
    homepage = "https://github.com/linode/linode-cli";
    description = "The Linode Command Line Interface";
    license = licenses.bsd3;
    maintainers = with maintainers; [ ryantm ];
  };

}
