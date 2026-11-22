# TODO List

## Overview
This file tracks tasks and features for the NixOS configuration following the dendritic pattern.

## Short-term Tasks
- [ ] Convert home-manager configuration to features pattern
- [ ] Organize configuration into modules/attrs and modules/features structure
- [ ] Ensure all features are properly exported and can be enabled per system

## Medium-term Tasks
- [ ] Add more feature modules following the dendritic pattern
- [ ] Improve build times and caching
- [ ] Document each feature module

## Long-term Tasks
- [ ] Refactor configuration for better maintainability
- [ ] Add CI/CD pipeline for configuration validation
- [ ] Create contribution guidelines

## Features Status
- [x] Git feature module
- [ ] Niri feature module
- [ ] Development tools feature module
- [ ] Security features

## Debugging Notes
- Need to investigate why home config is not building properly
- Check flake output consistency
- Verify module imports are correct
