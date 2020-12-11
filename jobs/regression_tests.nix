{ ... }: # ignore arguments

with import ../library.nix {
  default_vtr_rev = "";
  pkgs = import <nixpkgs> {}; # import default.nix, passing in nixpkgs
};

let
  vtr_hackerfoo_ri = vtrDerivation {
    variant = "vtr_hackerfoo_ri";
    url = "https://github.com/HackerFoo/vtr-verilog-to-routing.git";
    ref = "dont_add_nonconfig_congestion";
    rev = "392b973db050028af49f6e5a00b72a8b60ef5264";
  };
  regression_tests = make_regression_tests {
    vtr = vtr_hackerfoo_ri;
  };
in

# each attribute is a job
summariesOf {
  vtr_reg_basic = regression_tests.vtr_reg_basic;
  vtr_reg_strong = regression_tests.vtr_reg_strong;
  vtr_reg_nightly = regression_tests.vtr_reg_nightly;
  vtr_reg_weekly = regression_tests.vtr_reg_weekly;
}
