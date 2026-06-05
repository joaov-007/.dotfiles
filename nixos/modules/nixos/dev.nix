{lib, ...}: {
  options.dev.user = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Global developer name";
    };
    email = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Global developer email";
    };
  };
}
