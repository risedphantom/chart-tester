# chart-tester.sh

**`chart-tester.sh`** is a Bash utility for automating Helm chart dependency resolution, linting, debugging, and installation using metadata embedded in values YAML files. It supports Helm and Git-based charts and is designed for structured, metadata-driven Kubernetes deployment workflows.

## Features

- Parse values YAML files for Helm chart metadata
- Fetch charts from Helm repositories or Git sources
- Lint charts and render manifests to debug output
- Install charts to selected Kubernetes contexts
- Colorful CLI output for improved UX
- Metadata override support from both YAML and comments

## Metadata Format

Values files should include either inline YAML metadata or comment-based metadata:

```yaml
##-> Chart: my-service
##-> Version: 1.2.3
##-> Source: https://charts.example.com
##-> Type: helm
##-> Namespace: my-ns
##-> Release: my-release
##-> BaseValues: global.yaml,env/dev.yaml

chartInstallOptions:
  chart: my-service
  version: 1.2.3
  source: https://charts.example.com
  type: helm
  namespace: my-ns
  releaseName: my-release
  baseValues:
    - global.yaml
    - env/dev.yaml
```
