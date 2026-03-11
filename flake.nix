{
  description = "Fullstack Node app with Nix Flakes";

  # Inputs: Where we get our software from.
  # Using 'nixos-24.11' ensures stable, reproducible versions of Node, Bash, etc.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  };

  outputs =
    { self, nixpkgs }:
    let
      # system: Tells Nix which CPU/OS architecture to build for.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # devShells: Define the environment for 'nix develop'.
      # This is for coding locally, not for production.
      devShells.${system} = {
        default = pkgs.mkShellNoCC {
          packages = [
            pkgs.nodejs_22
            pkgs.sqlite
          ];

          shellHook = ''
            set -a
            if [ -f ./backend/.env ]; then
              source ./backend/.env
              echo "./backend/.env found and loaded"
            else
              echo "Create ./backend/.env"
            fi
            if [ -f ./frontend/.env ]; then
              source ./frontend/.env
              echo "./frontend/.env found and loaded"
            else
              echo "Create ./frontend/.env"
            fi
            set +a
          '';
        };
      };

      # packages: Definitions for building the actual software.
      packages.${system} = {

        # 1. BACKEND BUILD
        backend-prod = pkgs.buildNpmPackage {
          pname = "backend";
          version = "1.0.0";
          src = ./backend;

          # npmDepsHash: A security feature. Nix fetches all npm modules and hashes them.
          # If a dev adds a package to package.json, this hash MUST be updated.
          npmDepsHash = "sha256-SGr7plngpo4rLTCHf8vbBeX58Gr1XG59KSFmsqqTsnw=";
          nodejs = pkgs.nodejs_22;

          # We skip the build phase because this is a plain JS app (no TypeScript/Babel).
          dontNpmBuild = true;

          # postInstall: Custom logic to make the app "runnable".
          # Nix usually just copies files; we need to create a 'bin' script.
          postInstall = ''
mkdir -p $out/bin
# Create a wrapper script so we don't have to type 'node path/to/index.js'
# #!/bin/sh is the 'shebang' telling the OS this is a script.
cat <<EOF > $out/bin/backend
#!/bin/sh
exec ${pkgs.nodejs_22}/bin/node $out/lib/node_modules/backend/index.js
EOF
# Make the script executable, otherwise 'nix run' or Docker will fail.
chmod +x $out/bin/backend
          '';
        };

        # 2. FRONTEND BUILD (Vite)
        frontend-prod = pkgs.buildNpmPackage {
          pname = "frontend";
          version = "1.0.1";
          src = ./frontend;
          npmDepsHash = "sha256-Wg/jkaQbHGHQ+0jgXPTEW4sndeob7kXarxg7afUFckE=";
          nodejs = pkgs.nodejs_22;
          env = {
            VITE_API_URL = "https://backend.proclub.work";
          };
          npmBuildScript = "build";

          # installPhase: Tells Nix which files to keep in the final output.
          # We only care about the static 'dist' folder created by Vite.
          installPhase = ''
mkdir -p $out/dist
cp -r dist/* $out/dist/
mkdir -p $out/bin
cat <<EOF > $out/bin/frontend
#!/bin/sh
exec ${pkgs.nodejs_22}/bin/node ${pkgs.nodePackages.serve}/bin/serve -s $out/dist -l 8080
EOF
chmod +x $out/bin/frontend
          '';
        };

        # 3. BACKEND DOCKER IMAGE
        # buildLayeredImage: Creates an image where each dependency is its own layer.
        # This makes 'docker push/pull' very fast.
        backend-docker = pkgs.dockerTools.buildLayeredImage {
          name = "backend-prod";
          tag = "latest";
          # contents: Programs available inside the container.
          # We include bash for debugging and cacert for HTTPS requests.
          contents = [
            self.packages.${system}.backend-prod
            pkgs.bash
            pkgs.cacert
          ];
          config = {
            # Cmd: The command that runs when the container starts.
            Cmd = [ "/bin/backend" ];
            ExposedPorts = {
              "3001/tcp" = { };
            };
            Env = [
              "PORT=3001"
              "NODE_ENV=production"
            ];
          };
        };

        # 4. FRONTEND DOCKER IMAGE
        frontend-docker = pkgs.dockerTools.buildLayeredImage {
          name = "frontend-prod";
          tag = "latest";

          # We include 'serve' because static files need a web server to be seen in a browser.
          contents = [
            pkgs.nodejs_22
            pkgs.nodePackages.serve # Pre-built Nix package for 'serve'
            pkgs.cacert
            self.packages.${system}.frontend-prod
          ];

          config = {
            # -s: Single Page App mode (handles React/Vite routing)
            # -l 8080: Listen on port 8080
            Cmd = [
              "${pkgs.nodePackages.serve}/bin/serve"
              "-s"
              "${self.packages.${system}.frontend-prod}/dist"
              "-l"
              "8080"
            ];
            ExposedPorts = {
              "8080/tcp" = { };
            };
            Env = [
              "NODE_ENV=production"
            ];
          };
        };
      };

      # apps: Defines what happens when you run 'nix run .#name'
      apps.${system} = {
        backend = {
          type = "app";
          meta = {
            description = "Backend system";
          };
          program = "${self.packages.${system}.backend-prod}/bin/backend";
        };

        frontend = {
          type = "app";
          meta = {
            description = "Frontend static server";
          };
          program = "${self.packages.${system}.frontend-prod}/bin/frontend";
        };
      };
    };
}
