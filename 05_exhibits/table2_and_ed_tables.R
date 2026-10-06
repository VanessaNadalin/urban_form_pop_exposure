# =============================================================================
# table2_and_ed_tables.R
# Formats and exports Table 2 and ED Tables 3-6 from the model objects
# 04_regression_dataset_and_models/16_estimate_models.R already fitted and
# saved. Per CLAUDE.md's target structure and MIGRATION_PLAN.md 6d (applied
# 2026-09-11): stage 4 estimates, stage 5 formats. Nothing here re-estimates
# anything -- every coefficient, SE and N below comes straight from the
# saved model objects; this script only chooses labels, notes, and output
# format.
#
# Exhibit -> model object -> output file:
#   Table 2      <- tab_main_mun       -> table2_main_municipalities
#   ED Table 4   <- tab_mediators_mun  -> ed_table4_mediators
#   ED Table 5   <- tab_appA_arr       -> ed_table5_fua
#   ED Table 3   <- tab_horserace_mun  -> ed_table3_horserace
#   ED Table 6   <- tab_interact_mun   -> ed_table6_interactions
#
# The mediator-coefficients-shown variant (former "Table 3b", same models as
# ED Table 4 with a different coef_map to surface the mediators themselves)
# is NOT exported as a deliverable here -- decided 2026-09-10
# (05_exhibits/pipeline_5.md §9): it isn't in results_used.md, and ED Table 4
# already answers the with/without-mediators question. Its coef map is kept
# below, commented out, in case it's wanted again.
#
# Display conventions (all five tables):
#   - Column headers: a spanning header names the dependent variable, a
#     sub-header names the column. Columns are ordered so each dependent
#     variable is contiguous (ED Tables 4 and 6 are reordered for that; the
#     fitted models are untouched, only their display order and labels change).
#   - Two treatment rows, each filled only in its own columns.
#   - Coefficient rows come from coef_map alone. coef_omit is NOT used: it is
#     applied before coef_map and would silently drop mapped rows.
#   - Notes carry no internal variable names; the star legend is printed once.
#
# Input:
#   data/processed_data/04_regression/model_objects_table2.rds  (script 16)
#
# Outputs (in output/):
#   table2_main_municipalities.{html,tex,docx}
#   ed_table4_mediators.{html,tex,docx}
#   ed_table5_fua.{html,tex,docx}
#   ed_table3_horserace.{html,tex,docx}
#   ed_table6_interactions.{html,tex,docx}
# =============================================================================

source("04_regression_dataset_and_models/00_setup.R")
source("R/docx_tables.R")   # shared Word format (2026-09-30)

for (pkg in c("lmtest", "sandwich", "modelsummary", "flextable", "tinytable")) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

cat("\n", strrep("=", 60), "\n")
cat("TABLE2_AND_ED_TABLES.R\n")
cat(strrep("=", 60), "\n")

# =============================================================================
# 1) LOAD MODEL OBJECTS
# =============================================================================

cat("\n1) Loading model objects from script 16...\n")

rds_path <- file.path(data_dir, "model_objects_table2.rds")
if (!file.exists(rds_path))
  stop("model_objects_table2.rds not found — run 04_regression_dataset_and_models/16_estimate_models.R first.\n  Path: ", rds_path)

model_objects <- readRDS(rds_path)

tab_main_mun      <- model_objects$tab_main_mun
tab_appA_arr      <- model_objects$tab_appA_arr
tab_interact_mun  <- model_objects$tab_interact_mun
tab_mediators_mun <- model_objects$tab_mediators_mun
tab_horserace_mun <- model_objects$tab_horserace_mun
metadata          <- model_objects$metadata

MIN_POP_RISCO_2010 <- metadata$min_pop_risco_2010

cat(sprintf("   Estimated: %s\n", format(metadata$date_estimated)))
cat(sprintf("   Municipalities: %d -> %d after pop_2010_risk_total > %d\n",
            metadata$n_mun_pre_filter, metadata$n_mun_post_filter, MIN_POP_RISCO_2010))
cat(sprintf("   Region-interaction columns exclude Centro-Oeste: %d municipalities dropped\n",
            metadata$n_centro_oeste_dropped))

# =============================================================================
# 2) SHARED HELPERS (vcov functions are redefined here, not saved in the
#    .rds -- cheap to duplicate, avoids relying on serialized closures)
# =============================================================================

# vcov by dataset type:
#   municipalities -> clustered by arrangement (CD_CIDADE, via attr(mod, "cluster_vec"))
#   arrangements   -> HC3 (each row is already a unique cluster)
vcov_clust <- function(mod) {
  cl <- attr(mod, "cluster_vec")
  if (!is.null(cl)) vcovCL(mod, cluster = cl) else vcovHC(mod, type = "HC3")
}
vcov_hc3 <- function(mod) vcovHC(mod, type = "HC3")

gof_0010 <- tribble(
  ~raw,            ~clean,    ~fmt,
  "nobs",          "N",        0L,
  "r.squared",     "R²",       3L,
  "adj.r.squared", "R² adj.",  3L
)

# --- Display labels shared by all tables ---------------------------------------
# Wording as in the researcher's formatted Table 2 (2026-09-30): units of the
# treatment shares are in Extended Data Table 1, and p.p. abbreviates
# percentage points.
LAB_COMPACT <- "Compact share of urban footprint"
LAB_SPRAWL  <- "Sprawl share of urban footprint"
DV_G <- "Growth of population in risk, 2010–2022 (%)"
DV_D <- "Change in share of population in risk, 2010–2022 (p.p.)"

# Star legend, printed once (modelsummary's own legend is switched off below).
STARS      <- c("*" = .10, "**" = .05, "***" = .01)
NOTE_STARS <- "*P < 0.10, **P < 0.05, ***P < 0.01, two-sided"

# modelsummary 2.x prints its own star legend unless told otherwise; the
# argument name has varied across versions, so set the option and, when the
# argument exists, pass it as well.
options(modelsummary_stars_note = FALSE)
STARS_NOTE_ARG <- "stars_note" %in% names(formals(modelsummary::modelsummary))
if (!STARS_NOTE_ARG)
  warning("modelsummary() has no 'stars_note' argument in this version; ",
          "check that the star legend is not printed twice.")

# --- Layouts: fitted-model name -> displayed column name and dependent variable -
# Built by name (not position) so a reordering in 16_estimate_models.R fails
# loudly in save_table() instead of mislabelling columns.
layout_main <- tribble(                      # Table 2 and ED Table 5
  ~old,                       ~new,           ~dv,
  "(1) g_high — Compact",     "(1) Compact",  DV_G,
  "(2) g_high — Sprawl",      "(2) Sprawl",   DV_G,
  "(3) Dpp_high — Compact",   "(3) Compact",  DV_D,
  "(4) Dpp_high — Sprawl",    "(4) Sprawl",   DV_D
)

layout_horserace <- tribble(                 # ED Table 3 (no sub-headers)
  ~old,                              ~new,  ~dv,
  "(1) g_high — Compact + Sprawl",   "(1)", DV_G,
  "(2) Dpp_high — Compact + Sprawl", "(2)", DV_D
)

layout_mediators <- tribble(                 # ED Table 4, grouped by dependent variable
  ~old,                                            ~new,                          ~dv,
  "(1) g_high Compact — WITH mediators",           "(1) Compact, with mediators", DV_G,
  "(2) g_high Sprawl — WITH mediators",            "(2) Sprawl, with mediators",  DV_G,
  "(5) g_high Compact — NO mediators",             "(3) Compact, no mediators",   DV_G,
  "(6) g_high Sprawl — NO mediators",              "(4) Sprawl, no mediators",    DV_G,
  "(9) g_high — Mediators ONLY (no treatment)",    "(5) Mediators only",          DV_G,
  "(3) Dpp_high Compact — WITH mediators",         "(6) Compact, with mediators", DV_D,
  "(4) Dpp_high Sprawl — WITH mediators",          "(7) Sprawl, with mediators",  DV_D,
  "(7) Dpp_high Compact — NO mediators",           "(8) Compact, no mediators",   DV_D,
  "(8) Dpp_high Sprawl — NO mediators",            "(9) Sprawl, no mediators",    DV_D,
  "(10) Dpp_high — Mediators ONLY (no treatment)", "(10) Mediators only",         DV_D
)

layout_interact <- tribble(                  # ED Table 6, grouped by dependent variable
  ~old,                                   ~new,                          ~dv,
  "(1) g_high — Compact × urban_class",   "(1) Compact × urban class",   DV_G,
  "(3) g_high — Compact × regiao",        "(2) Compact × region",        DV_G,
  "(5) g_high — Sprawl × urban_class",    "(3) Sprawl × urban class",    DV_G,
  "(7) g_high — Sprawl × regiao",         "(4) Sprawl × region",         DV_G,
  "(2) Dpp_high — Compact × urban_class", "(5) Compact × urban class",   DV_D,
  "(4) Dpp_high — Compact × regiao",      "(6) Compact × region",        DV_D,
  "(6) Dpp_high — Sprawl × urban_class",  "(7) Sprawl × urban class",    DV_D,
  "(8) Dpp_high — Sprawl × regiao",       "(8) Sprawl × region",         DV_D
)

# Reorders/renames the fitted models per `layout`, adds one spanning header per
# dependent variable (tinytable::group_tt), and writes html, tex and docx.
# The table is rebuilt for each format because "%" in a spanning label must be
# escaped in LaTeX only (modelsummary escapes captions, notes and cell text
# itself, but not group labels added afterwards).
save_table <- function(models, title, base_name, opts, layout) {
  missing_models <- setdiff(layout$old, names(models))
  if (length(missing_models) > 0)
    stop("Model(s) not found in ", base_name, ": ",
         paste(missing_models, collapse = "; "))
  models <- models[layout$old]
  if (any(vapply(models, is.null, logical(1))))
    stop("A model failed to estimate for ", base_name, "; see script 16's log.")
  names(models) <- layout$new

  # Model columns start at j = 2 (j = 1 is the row-label column).
  spans <- lapply(split(layout$new, factor(layout$dv, levels = unique(layout$dv))),
                  function(nm) match(nm, names(models)) + 1L)

  for (ext in c("html", "tex")) {
    tab <- do.call(modelsummary,
                   c(list(models = models, title = title, output = "tinytable"), opts))
    spans_ext <- spans
    if (ext == "tex") names(spans_ext) <- gsub("%", "\\\\%", names(spans_ext))
    tab <- tinytable::group_tt(tab, j = spans_ext)
    tinytable::save_tt(tab, output_path(paste0(base_name, ".", ext)), overwrite = TRUE)
    cat(sprintf("  OK %s.%s\n", base_name, ext))
  }
  save_docx(models, title, base_name, opts, layout)
}

# The .docx in the shared Word format (R/docx_tables.R). Sub-headers drop the
# "(1)" column numbers; when that leaves them empty (ED Table 3, one column
# per dependent variable) the dependent variable becomes the only header row.
# Title and notes go outside the table.
save_docx <- function(models, title, base_name, opts, layout) {
  ft <- do.call(modelsummary,
                c(list(models = models, output = "flextable"),
                  opts[setdiff(names(opts), "notes")]))
  keys <- ft$col_keys
  sub_lab <- sub("^\\(\\d+\\)\\s*", "", layout$new)
  if (all(sub_lab == "")) {
    ft <- flextable::set_header_labels(ft, values = setNames(as.list(c("", layout$dv)), keys))
  } else {
    ft <- flextable::set_header_labels(ft, values = setNames(as.list(c("", sub_lab)), keys))
    runs <- rle(layout$dv)
    ft <- flextable::add_header_row(ft, values = c("", runs$values),
                                    colwidths = c(1L, runs$lengths))
  }
  # Rule above the goodness-of-fit rows (N, R², R² adj.).
  last_coef_row <- flextable::nrow_part(ft, "body") - nrow(gof_0010)
  ft <- style_docx_table(ft, rule_after_body_row = last_coef_row)
  write_docx_table(ft, title, opts$notes, output_path(paste0(base_name, ".docx")))
  cat(sprintf("  OK %s.docx\n", base_name))
}

make_opts <- function(coef_map, vcov, notes) {
  opts <- list(stars = STARS, coef_map = coef_map, gof_map = gof_0010,
               vcov = vcov, notes = notes)
  if (STARS_NOTE_ARG) opts$stars_note <- FALSE
  opts
}

# --- Note building blocks (plain language, no internal variable names) ---------
# `units` is the observation unit in the plural, capitalised ("Municipalities").
NOTE_DEFS <- "Variable definitions in Extended Data Table 1."

note_sample <- function(units)
  sprintf("%s with %d or fewer residents in risk areas in 2010 are excluded.",
          units, MIN_POP_RISCO_2010)

NOTE_SE_CLUSTER <- "Standard errors clustered by functional urban area in parentheses."
NOTE_SE_HC3     <- "HC3 heteroskedasticity-robust standard errors in parentheses."

# Vacant safe land Q4 is undefined where a municipality has no cells in its
# arrangement's top income quartile; 16_estimate_models.R's prep() sets it to 0
# there and adds an indicator, which enters every specification with Q4
# (2026-09-30).
NOTE_Q4 <- paste("Vacant safe land Q4 is set to 0 for municipalities with no cells in",
                 "their arrangement's top income quartile, and an indicator for those",
                 "municipalities is included (not shown).")
NOTE_CTRL_LOGS <- paste("Controls included but not shown: median rent, 2010;",
                        "log GDP per capita, 2010;",
                        "log total population, 2000; log urban footprint, 2000;",
                        "indicator for no urban footprint in 2000;",
                        "region and urban-class indicators.")
NOTE_CTRL_FULL <- paste("Controls included but not shown: log GDP per capita, 2010;",
                        "indicator for no urban footprint in 2000;",
                        "region and urban-class indicators.")
# Municipal tables only: at arrangement level Q4 is defined for every unit, so
# the indicator is constant there and aliased out (ED Table 5 keeps the base note).
NOTE_CTRL_LOGS_MUN <- paste(NOTE_CTRL_LOGS, NOTE_Q4)
NOTE_CTRL_FULL_MUN <- paste(NOTE_CTRL_FULL, NOTE_Q4)

cat("\n2) Formatting and saving tables to output/...\n")

# =============================================================================
# 3) TABLE 2 — main table (body of the article), municipalities
# =============================================================================

# Rows displayed in Table 2 and, with the same pattern, ED Tables 3 and 5.
# log_pop_total_2000 and log_area_2000_km2 are estimated but not displayed
# (listed in the note); ED Table 4 adds them back (coef_map_full below).
coef_map_main <- c(
  "pct_area_densif_infill_0010"         = LAB_COMPACT,
  "pct_area_periph_ext_leap_0010"       = LAB_SPRAWL,
  "g_fora_alta"                         = "Pop growth outside risk",
  "pp_alta_2010"                        = "Pop share in risk, 2010",
  "topo_prop_inclinado"                 = "Steep terrain",
  "pct_nao_constru_fora_alta_2010_q1"   = "Vacant safe land, Q1, 2010",
  "pct_nao_constru_fora_alta_2010_q4_f" = "Vacant safe land, Q4, 2010",
  "palma_commute"                       = "Palma ratio commute, 2010",
  "palma_rent"                          = "Palma ratio rents, 2010",
  "prop_favelas_2010"                   = "Slum population share, 2010",
  "(Intercept)"                         = "Intercept"
)
# Median rent is estimated but not displayed in Table 2 and ED Tables 3, 5 and 6
# (listed in their note), as in the researcher's formatted Table 2
# (2026-09-30). ED Table 4 keeps it: it is one of the mediators that table
# removes and restores (inserted after the Palma ratio of rents below).

# ED Table 4 shows the full coefficient set: the two log controls follow the
# treatment rows, as in the agreed row order.
coef_map_full <- c(
  coef_map_main[c("pct_area_densif_infill_0010", "pct_area_periph_ext_leap_0010")],
  "log_pop_total_2000"                  = "Log total population, 2000",
  "log_area_2000_km2"                   = "Log urban footprint, 2000",
  append(coef_map_main[-(1:2)], c("median_rent" = "Median rent, 2010"),
         after = match("palma_rent", names(coef_map_main[-(1:2)])))
)

note_main <- c(
  paste(NOTE_DEFS, NOTE_SE_CLUSTER,
        note_sample("Municipalities"), NOTE_CTRL_LOGS_MUN),
  NOTE_STARS
)

save_table(
  tab_main_mun,
  paste("Table 2 — Pre-period urban form (2000–2010) and population in risk (2010–2022):",
        "municipalities."),
  "table2_main_municipalities",
  make_opts(coef_map_main, vcov_clust, note_main),
  layout_main
)

# =============================================================================
# 4) ED TABLE 5 — arrangements (functional urban areas), high susceptibility
# =============================================================================

note_arr <- c(
  paste(NOTE_DEFS, NOTE_SE_HC3,
        note_sample("Functional urban areas"), NOTE_CTRL_LOGS),
  NOTE_STARS
)

save_table(
  tab_appA_arr,
  paste("ED Table 5 — Pre-period urban form (2000–2010) and population in risk (2010–2022):",
        "functional urban areas."),
  "ed_table5_fua",
  make_opts(coef_map_main, vcov_hc3, note_arr),
  layout_main
)

# =============================================================================
# 5) ED TABLE 6 — interactions (urban_class + regiao, compact + sprawl)
# =============================================================================

# Interaction labels are unchanged from the previous version. The compact and
# sprawl interactions share labels: modelsummary merges them into one row, and
# each row is filled only in the columns whose model contains that term.
coef_map_interact <- c(
  # Compact: main effect and interactions
  coef_map_main["pct_area_densif_infill_0010"],
  "pct_area_densif_infill_0010:urban_classMetropolises" = "  × Metropolises",
  "pct_area_densif_infill_0010:urban_classMetropolis Suburbs" = "  × Metropolis Suburbs",
  "pct_area_densif_infill_0010:urban_classRegional Centers" = "  × Regional Centers",
  "pct_area_densif_infill_0010:urban_classRegional Centers Suburbs" = "  × Regional Centers Suburbs",
  "pct_area_densif_infill_0010:regiaoSul" = "  × South",
  "pct_area_densif_infill_0010:regiaoNordeste" = "  × Northeast",
  "pct_area_densif_infill_0010:regiaoNorte" = "  × North",
  # Sprawl: main effect and interactions
  coef_map_main["pct_area_periph_ext_leap_0010"],
  "pct_area_periph_ext_leap_0010:urban_classMetropolises" = "  × Metropolises",
  "pct_area_periph_ext_leap_0010:urban_classMetropolis Suburbs" = "  × Metropolis Suburbs",
  "pct_area_periph_ext_leap_0010:urban_classRegional Centers" = "  × Regional Centers",
  "pct_area_periph_ext_leap_0010:urban_classRegional Centers Suburbs" = "  × Regional Centers Suburbs",
  "pct_area_periph_ext_leap_0010:regiaoSul" = "  × South",
  "pct_area_periph_ext_leap_0010:regiaoNordeste" = "  × Northeast",
  "pct_area_periph_ext_leap_0010:regiaoNorte" = "  × North",
  # Controls: the same rows as Table 2
  coef_map_main[-(1:2)]
)

note_interact <- c(
  paste(NOTE_DEFS, NOTE_SE_CLUSTER,
        note_sample("Municipalities"),
        "Reference categories: Urban Centers (urban class) and Southeast (region).",
        "The first row of each treatment block gives the association in the reference",
        "category; the × rows give the differential association relative to it.",
        sprintf(paste("The region-interaction columns exclude the %d Centro-Oeste",
                      "municipalities left after the restriction, too few for its",
                      "interaction terms to be estimated."),
                metadata$n_centro_oeste_dropped),
        "Sample sizes differ across columns because observations with missing values",
        "in a column's variables are dropped.",
        NOTE_CTRL_LOGS_MUN),
  NOTE_STARS
)

save_table(
  tab_interact_mun,
  "ED Table 6 — Interactions with urban class and region.",
  "ed_table6_interactions",
  make_opts(coef_map_interact, vcov_clust, note_interact),
  layout_interact
)

# =============================================================================
# 6) ED TABLE 4 — mediator test (with vs. without housing-market mediators)
# =============================================================================

note_mediators <- c(
  paste(NOTE_DEFS, NOTE_SE_CLUSTER,
        note_sample("Municipalities"),
        "Housing-market mediators are median rent, the Palma ratios, vacant safe land",
        "(Q1 and Q4) and the slum population share; columns without mediators omit them, and the 'Mediators only'",
        "columns omit the two urban footprint share variables, to check whether the",
        "mediators predict the outcome without the treatment.",
        NOTE_CTRL_FULL_MUN),
  NOTE_STARS
)

save_table(
  tab_mediators_mun,
  "ED Table 4 — Mediation test: effect of removing housing-market mediator variables.",
  "ed_table4_mediators",
  make_opts(coef_map_full, vcov_clust, note_mediators),
  layout_mediators
)

# -- Mediator-coefficients-shown variant: NOT exported, see header note -----
# coef_map_mediators_show <- c(
#   "pct_area_densif_infill_0010"        = "Treatment: Compact growth",
#   "pct_area_periph_ext_leap_0010"      = "Treatment: Sprawl growth",
#   "median_rent"                        = "Median rent 2010",
#   "palma_rent"                         = "Palma ratio: rent 2010",
#   "palma_commute"                      = "Palma ratio: commute 2010",
#   "pct_nao_constru_fora_alta_2010_q1" = "Safe empty land Q1 (low availability)",
#   "pct_nao_constru_fora_alta_2010_q4" = "Safe empty land Q4 (high availability)",
#   "pp_alta_2010"                       = "Pop. share in risk zones 2010",
#   "g_fora_alta"                        = "Pop. growth outside risk zones",
#   "topo_prop_inclinado"                = "Steep terrain",
#   "log_pop_total_2000"                 = "Log total population 2000",
#   "(Intercept)"                        = "Intercept"
# )

# =============================================================================
# 7) ED TABLE 3 — horse race (compact and sprawl entered jointly)
# =============================================================================

note_horserace <- c(
  paste(NOTE_DEFS, NOTE_SE_CLUSTER,
        note_sample("Municipalities"),
        "Both variables enter the same regression; each coefficient is measured relative",
        "to consolidated urban area, the omitted category.",
        NOTE_CTRL_LOGS_MUN),
  NOTE_STARS
)

save_table(
  tab_horserace_mun,
  "ED Table 3 — Horse race: compact and sprawl shares of urban footprint in the same regression.",
  "ed_table3_horserace",
  make_opts(coef_map_main, vcov_clust, note_horserace),
  layout_horserace
)

cat("\n", strrep("=", 60), "\n")
cat("DONE\n")
cat(strrep("=", 60), "\n")
cat("\nOutputs in: ", output_dir, "\n")
