{
  lib,
  buildNpmPackage,
  autoPatchelfHook,
  stdenv,
}:
buildNpmPackage {
  pname = "pi-fff";
  version = "0.11.0";

  src = ./.;

  npmDepsHash = "sha256-m9ZvYmjbInTiyu8xeR7SMXyNCaEQje4mVi8nFWMY8gM=";
  npmFlags = ["--legacy-peer-deps"];
  dontNpmBuild = true;

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp -r node_modules $out/lib/node_modules

    runHook postInstall
  '';

  meta = {
    description = "Pi FFF extension with its native Rust search library";
    homepage = "https://github.com/dmtrKovalenko/fff";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
