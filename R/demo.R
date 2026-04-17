#' Load a small clinical-trial-like demo dataframe + open the chat
#'
#' For first-time users who want to see sparx in action immediately.
#' Creates `trial_demo` in .GlobalEnv: 120 rows of simulated blood-pressure
#' trial data with treatment (Control / Drug A / Drug B), age, sex,
#' bp_before, bp_after, and hospital site. Then opens the chat with a
#' suggested starter prompt.
#'
#' This is simulated data, not from a real trial. Don't use it for science.
#'
#' @export
#' @examples
#' \dontrun{
#' sparx::demo_workflow()
#' }
demo_workflow <- function() {
  set.seed(42)
  n <- 120
  trt <- factor(sample(c("Control", "Drug A", "Drug B"), n, replace = TRUE))
  effect <- c(Control = 0, `Drug A` = -8, `Drug B` = -14)[as.character(trt)]
  age <- round(rnorm(n, mean = 58, sd = 11))
  sex <- factor(sample(c("F", "M"), n, replace = TRUE))
  hospital <- factor(sample(paste0("Hospital_", 1:5), n, replace = TRUE))
  bp_before <- round(rnorm(n, mean = 148, sd = 12))
  noise <- rnorm(n, mean = 0, sd = 6)
  age_effect <- (age - 58) * 0.15
  bp_after <- round(bp_before + effect + age_effect + noise)

  trial_demo <- data.frame(
    patient_id = sprintf("P%03d", seq_len(n)),
    treatment = trt,
    age = age,
    sex = sex,
    hospital = hospital,
    bp_before = bp_before,
    bp_after = bp_after
  )

  # Introduce some realism: a few missing values
  trial_demo$bp_after[sample(n, 4)] <- NA_real_

  assign("trial_demo", trial_demo, envir = globalenv())

  message(
    "\u25cf trial_demo loaded: ", n, " rows \u00d7 7 cols.\n",
    "  Columns: patient_id, treatment, age, sex, hospital, bp_before, bp_after\n",
    "  (Simulated blood-pressure trial data \u2014 not real.)\n",
    "\n",
    "Opening sparx chat..."
  )

  # Stash a demo starter prompt so the chat opens with a useful suggestion
  .sparx_state$pending_prompt <- paste(
    "Inspect trial_demo.",
    "Check whether blood-pressure reduction (bp_after - bp_before) differs",
    "significantly across the three treatment groups.",
    "Adjust for age. Check assumptions. Report effect size and a clean",
    "APA-style summary."
  )

  open_chat()
}
