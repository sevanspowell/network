{ config, pkgs, ... }:

{
  networking.firewall = {
    allowedUDPPorts = [ 5439 5350 ];
    allowedTCPPorts = [ 80 443 3478 3479 ];
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      ## virtual host for Syapse
      "matrix.test.net" = {
        ## for force redirecting HTTP to HTTPS
        # forceSSL = true;
        ## this setting takes care of all LetsEncrypt business
        # enableACME = true;
        locations."/" = {
          proxyPass = "http://localhost:8090";
        };
      };
    };
  };

  services.matrix-synapse = {
    enable = true;

    server_name = "matrix.test.net";

    enable_metrics = true;

    enable_registration = true;

    ## Synapse guys recommend to use PostgreSQL over SQLite
    database_type = "psycopg2";

     ## database setup clarified later
     database_args = {
       password = "synapse";
     };

     ## default http listener which nginx will passthrough to
     listeners = [
       {
         port = 8090;
         tls = false;
         resources = [
           {
             compress = true;
             names = ["client" "webclient" "federation"];
           }
         ];
       }
     ];
   };

   services.postgresql = {
     enable = true;

     ## postgresql user and db name remains in the
     ## service.matrix-synapse.database_args setting which
     ## by default is matrix-synapse
     initialScript = pkgs.writeText "synapse-init.sql" ''
         CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
         CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
             TEMPLATE template0
             LC_COLLATE = "C"
             LC_CTYPE = "C";
         '';
   };

   environment = {
     systemPackages = with pkgs; [
       element-web
     ];
   };

   nixpkgs.overlays = [
     (self: super: {
       element-web = super.element-web.override {
         conf = {
           default_server_config = {
             "m.homeserver" = {
               "base_url" = "https://matrix.test.net";
               "server_name" = "matrix.test.net";
             };
             "m.identity_server" = {
               "base_url" = "https://vector.im";
             };
           };

           ## jitsi will be setup later,
           ## but we need to add to Riot configuration
           jitsi.preferredDomain = "jitsi.dangerousdemos.net";
         };
       };
     })
   ];
}
