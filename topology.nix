{
  wireguard = {
    addr = { ip = "10.100.0.0"; mask = "24" };

    server = {
      ip = "10.100.0.1";
      publicKey = "nUc1O2ASgcpDcov/T/LzSxleaH1TpW1vpdCofaSq9zw="
    };

    orchid = {
      ip = "10.100.0.2";
      publicKey = "";
    };
  };
}
