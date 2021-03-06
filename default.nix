# test runs
#
# configuration for make_regression_tests:
# flags: passed to vpr for each task
# vtr.variant: an identifier for a specific variant
# vtr.url: location of the VTR repo
# vtr.rev: git revision
# vtr.patches: list of patches to apply to VTR
{ pkgs ? import <nixpkgs> {}, ... }:

with pkgs;
with lib;
with import ./library.nix {
  inherit pkgs;

  # default VTR revision
  default_vtr_rev = "b4f390a7d9ae9a566944a5dbb8d89cd2498a79f1";
};

rec {
  # unmodified tests
  regression_tests = make_regression_tests {};

  vtr_dusty_sa = vtrDerivation {
    variant = "dusty_sa";
    url = "https://github.com/HackerFoo/vtr-verilog-to-routing.git";
    ref = "dusty_sa";
    rev = "b46fd7d22f25fb0f787ce2e7217d44f4960aad6b";
  };

  vtr_node_reordering = vtrDerivation {
    variant = "node_reordering_flag";
    url = "https://github.com/HackerFoo/vtr-verilog-to-routing.git";
    ref = "node_reordering_flag";
    rev = "7872c8f6cb32efb988138b50e3caf198bb2212ac";
  };

  vtr_node_reordering_may5 = vtrDerivation {
    variant = "node_reordering_flag_may5";
    url = "https://github.com/HackerFoo/vtr-verilog-to-routing.git";
    ref = "node_reordering_flag";
    rev = "fb381c011f3b83deb1c63275ee0b923ea9c8151c";
  };

  # a sweep over a few values of --inner_num
  dot_to_us = builtins.replaceStrings ["."] ["_"];
  make_inner_num_sweep = test_type: fn: values: builtins.listToAttrs (map (val: {
    name = "${test_type}_inner_num_${dot_to_us val}";
    value = (make_regression_tests (fn val)).${test_type};
  }) values);
  make_inner_num_sweep_comparison = test_type: values: opts: addAll "inner_num_sweep_${test_type}" {
    baseline = addAll "baseline" (make_inner_num_sweep test_type (val: { flags = "--inner_num ${val}"; } // opts) values);
    no_flag = addAll "no_flag" (make_inner_num_sweep test_type (val: { vtr = vtr_dusty_sa; flags = "--inner_num ${val}"; } // opts) values);
    with_flag = addAll "with_flag" (make_inner_num_sweep test_type (val: { vtr = vtr_dusty_sa; flags = "--alpha_min 0.2 --inner_num ${val}"; } // opts) values);
  };
  inner_num_sweep_weekly = make_inner_num_sweep_comparison "vtr_reg_weekly_no_he" ["0.5" "1.0" "2.0"] { };
  inner_num_sweep_nightly = make_inner_num_sweep_comparison "vtr_reg_nightly" ["0.125" "0.25" "0.5" "1.0" "2.0"] { run_id = "1"; };
  inner_num_sweep_nightly_2 = make_inner_num_sweep_comparison "vtr_reg_nightly" ["0.125" "0.25" "0.5" "1.0" "2.0"] { run_id = "2"; };
  inner_num_sweep_nightly_3 = make_inner_num_sweep_comparison "vtr_reg_nightly" ["0.125" "0.25" "0.5" "1.0" "2.0"] { run_id = "3"; };
  dusty_sa = make_regression_tests { vtr = vtr_dusty_sa; flags = "--alpha_min 0.2"; };
  inner_num_sweep_with_flag_high = addAll "with_flag" (make_inner_num_sweep "vtr_reg_nightly" (val: { run_id = "with_flag_high"; vtr = vtr_dusty_sa; flags = "--alpha_min 0.2 --inner_num ${val}"; }) ["4.0" "10.0"]);

  dusty_sa_sweep =
    let test = {root, flags}:
          if flags.anneal_success_min >= flags.anneal_success_target then null else
          (make_regression_tests {
            vtr = vtr_dusty_sa;
            flags = flags_to_string flags;
          }).vtr_reg_nightly.titan_quick_qor.all;
    in
      flag_sweep "dusty_sa_sweep" test {
        alpha_min = [0.4 0.5 0.7 0.8];
        alpha_max = [0.9 0.95 0.99];
        alpha_decay = [0.7 0.6 0.5 0.4];
        anneal_success_target = [0.4 0.5 0.6];
        anneal_success_min = [0.1 0.15];
      };

  baseline_inner_num_sweep =
    let test = {flags, ...}:
          (make_regression_tests {
            flags = flags_to_string flags;
          }).vtr_reg_weekly.vtr_reg_titan.all;
    in
      flag_sweep "baseline_inner_num_sweep" test {
        inner_num = [0.25 0.5 1.0 2.0];
        seed = range 1 20;
    };

  dusty_sa_new_inner_num_sweep =
    let test = {flags, ...}:
          (make_regression_tests {
            vtr = vtr_dusty_sa;
            flags = flags_to_string (flags // {
              alpha_min = 0.8;
              alpha_max = 0.9;
              alpha_decay = 0.4;
              anneal_success_target = 0.6;
              anneal_success_min = 0.15;
            });
          }).vtr_reg_weekly.vtr_reg_titan.all;
    in
      flag_sweep "dusty_sa_new_inner_num_sweep" test {
        inner_num = [0.5 1 2 3 4];
        seed = range 1 10;
    };

  node_reordering =
    let test = {flags, ...}:
          (make_regression_tests {
            vtr = vtr_node_reordering_may5;
            flags = if flags.reorder_rr_graph_nodes_threshold == (-1)
                    then "" # default
                    else flags_to_string flags;
          }).vtr_reg_nightly.titan_quick_qor.all;
    in
      flag_sweep "node_reordering" test {
        reorder_rr_graph_nodes_threshold = [(-1) 1];
        reorder_rr_graph_nodes_algorithm = ["degree_bfs" "random_shuffle"];
      };

  various_seeds =
    let test = {flags, ...}:
          (make_regression_tests {
            flags = flags_to_string flags;
          }).vtr_reg_nightly.titan_quick_qor.stratixiv_arch.sparcT1_core_stratixiv_arch_timing.common;
    in
      flag_sweep "various_seeds" test {
        seed = range 1 960;
      };

  many_runs =
    let test = {flags, ...}:
          (make_regression_tests flags).vtr_reg_nightly.titan_quick_qor.stratixiv_arch.sparcT1_core_stratixiv_arch_timing.common;
    in
      flag_sweep "many_runs" test {
        run_id = range 1 960;
      };

  dusty_sa_no_flags =
    let test = {flags, ...}:
          (make_regression_tests {
            vtr = vtr_dusty_sa;
            flags = flags_to_string flags;
          }).vtr_reg_weekly.all;
    in
      flag_sweep "dusty_sa_no_flags" test {
        seed = range 1 20;
      };

  mohameds_test = attrs:
    make_regression_tests (attrs // {
      tests = {
        custom = {
          task = "mohameds_test/custom";
          qor_parse_file = "qor_standard.txt";
          pass_requirements_file = "pass_requirements.txt";
          arch_list = ["k6_frac_N10_frac_chain_mem32K_40nm.xml"];
          circuit_list = ["bgm.v" "LU8PEEng.v" "LU32PEEng.v" "mcml.v" "stereovision0.v" "stereovision1.v" "stereovision2.v"];
          archs_dir = "arch/timing";
          circuits_dir = "benchmarks/verilog";
          script_params = "-track_memory_usage --routing_failure_predictor off";
          parse_file = "vpr_standard.txt";
        };
      };
    });

  vtr_directed_moves = vtrDerivation {
    variant = "directed_moves";
    url = "ssh://git@github.com/MohamedElgammal/directed_moves.git";
    ref = "directed_moves";
    rev = "d5e85c1f37cb1d2675a9c63230b72bf6e85ab487";
  };

  directed_moves_sweep =
    let test = { flags, ...}: (mohameds_test {
          flags = "--simpleRL_agent_placement on ${flags_to_string flags}";
          vtr = vtr_directed_moves;
        }).custom;
    in
      flag_sweep "directed_moves_sweep" test {
        place_agent_gamma = [0.0005 0.001 0.005 0.01 0.05 0.1 0.5];
        place_agent_epsilon = [0.05 0.1 0.2 0.3 0.4 0.5 0.9];
        inner_num = [0.125 0.25 0.5 1 2];
        seed = range 1 5;
      };
}
