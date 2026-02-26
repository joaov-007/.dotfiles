{
  inputs,
  system,
  ...
}: self: super: {
  stable = import inputs.nixpkgs-stable {
    inherit self;
    inherit system;
    config.allowUnfree = true;
  };
}
