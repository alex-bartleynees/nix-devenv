{
  description = "Kubernetes development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        # Kind cluster configuration
        kindConfig = pkgs.writeText "kind-config.yaml" ''
          kind: Cluster
          apiVersion: kind.x-k8s.io/v1alpha4
          nodes:
            - role: control-plane
              kubeadmConfigPatches:
                - |
                  kind: InitConfiguration
                  nodeRegistration:
                    kubeletExtraArgs:
                      node-labels: "ingress-ready=true"
              extraPortMappings:
                - containerPort: 80
                  hostPort: 80
                  protocol: TCP
                - containerPort: 443
                  hostPort: 443
                  protocol: TCP
        '';

        # Shell script to initialize the Kind cluster
        initScript = pkgs.writeScriptBin "init-cluster" ''
          #!${pkgs.bash}/bin/bash
          if ! kind get clusters | grep -q "dev-cluster"; then
            echo "Creating Kind cluster..."
            kind create cluster --name dev-cluster --config ${kindConfig}
          else
            echo "Cluster 'dev-cluster' already exists"
          fi
        '';

      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            kubectl
            kind
            kubernetes-helm
            k9s
            initScript
          ];

          shellHook = ''
            echo "Kubernetes Development Environment"
            echo "Available commands:"
            echo "  - kubectl: Kubernetes command-line tool"
            echo "  - kind: Kubernetes in Docker"
            echo "  - k9s: Kubernetes CLI UI"
            echo "  - init-cluster: Initialize the Kind cluster with the provided configuration"
          '';
        };
      }
    );
}
