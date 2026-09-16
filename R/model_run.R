# ---------------------------------------------------------------------------
# ModelsCloud API surface for the FEV1 decline model.
#
# Zafari Z, Sin DD, Postma DS, et al. Individualized prediction of lung-function
# decline in chronic obstructive pulmonary disease. CMAJ. 2016;188(14):1004-1011.
# doi:10.1503/cmaj.151483
#
# The model itself is resplab/fev1; nothing here re-implements it. This file
# only adapts the calling convention: JSON fields in, a tidy projection out.
# ---------------------------------------------------------------------------

# Predictors the wrapper accepts. The four `fev1` projection models need
# different subsets; model 3 (the default, and the one the published calculator
# uses) needs everything in .fev1_required plus int_effect and tio.
.fev1_required <- c("fev1_0", "age", "height", "weight", "male", "smoking")
.fev1_optional <- c("int_effect", "tio", "prediction_model")
.fev1_vars <- c(.fev1_required, .fev1_optional)

# Accepted aliases (alias -> canonical), so the obvious spellings work.
.fev1_alias <- c(
  fev1 = "fev1_0", baseline_fev1 = "fev1_0", fev1_baseline = "fev1_0",
  sex = "male", gender = "male",
  smoking_status = "smoking", current_smoker = "smoking", smoker = "smoking",
  height_m = "height", weight_kg = "weight",
  tiotropium = "tio", intervention_effect = "int_effect",
  model = "prediction_model"
)

# Map "male"/"female" (or 0/1) onto the model's male indicator. The underlying
# model multiplies this by a coefficient, so a silently-miscoded sex shifts
# every projected year rather than failing loudly.
.fev1_male <- function(x) {
  if (is.numeric(x)) {
    if (!x %in% c(0, 1)) stop("Numeric `male`/`sex` must be 0 or 1.", call. = FALSE)
    return(as.integer(x))
  }
  key <- tolower(trimws(as.character(x)))
  if (key %in% c("male", "m", "man", "1", "true")) return(1L)
  if (key %in% c("female", "f", "woman", "0", "false")) return(0L)
  stop('Unrecognised `sex`/`male` value: "', x, '". Use "male"/"female" or 1/0.',
       call. = FALSE)
}

.fev1_smoking <- function(x) {
  if (is.numeric(x)) {
    if (!x %in% c(0, 1)) stop("Numeric `smoking` must be 0 or 1.", call. = FALSE)
    return(as.integer(x))
  }
  key <- tolower(trimws(as.character(x)))
  if (key %in% c("current", "smoker", "yes", "y", "1", "true")) return(1L)
  if (key %in% c("former", "quit", "ex-smoker", "no", "n", "0", "false")) return(0L)
  stop('Unrecognised `smoking` value: "', x, '". Use 1/0 or "current"/"former".',
       call. = FALSE)
}

.fev1_normalize <- function(model_input, dots) {
  if (is.null(model_input)) {
    if (length(dots) == 0) return(NULL)
    model_input <- dots
  }
  if (is.list(model_input) && !is.data.frame(model_input)) {
    model_input <- model_input[!vapply(model_input, is.null, logical(1))]
    if (length(model_input) == 0) return(NULL)
  }
  df <- as.data.frame(model_input, stringsAsFactors = FALSE)
  names(df) <- tolower(names(df))
  for (a in intersect(names(df), names(.fev1_alias))) {
    canon <- .fev1_alias[[a]]
    if (!canon %in% names(df)) names(df)[match(a, names(df))] <- canon
  }
  df[, intersect(names(df), .fev1_vars), drop = FALSE]
}

#' Project FEV1 decline (ModelsCloud entry point)
#'
#' Projects one patient's FEV1 trajectory over a 16-year horizon under two
#' scenarios — continued smoking and sustained quitting — using the model of
#' Zafari et al. (*CMAJ* 2016).
#'
#' @details
#' Inputs may arrive **wrapped** under `model_input` or **unwrapped** as named
#' arguments, and common aliases are mapped to canonical names (`fev1` ->
#' `fev1_0`, `sex` -> `male`, `tiotropium` -> `tio`).
#'
#' **Height must be in metres.** The model multiplies height and height-squared
#' by large coefficients, so a value in centimetres produces a confidently
#' wrong trajectory rather than an error. Values above 3 are rejected for that
#' reason rather than silently converted — a rejected call is recoverable, a
#' plausible-looking wrong answer is not.
#'
#' @param model_input A named list (or one-row data frame) of predictors:
#'   `fev1_0` (baseline FEV1, litres), `age` (years), `height` (**metres**),
#'   `weight` (kg), `male` (1/0, or `sex` as `"male"`/`"female"`), and
#'   `smoking` (1 = current smoker, 0 = sustained quitter). Optional:
#'   `int_effect` (intervention effect on lung function, litres; default 0),
#'   `tio` (tiotropium, `"Yes"`/`"No"`; default `"No"`), and
#'   `prediction_model` (1-4; default 3). If `NULL` and nothing is supplied
#'   via `...`, [get_default_input()] is used.
#' @param ... Alternative to `model_input`: the fields as named arguments.
#'
#' @return A data frame with one row per projected year per scenario:
#'   `Year` (0-15), `FEV1` (predicted litres), `variance`, `FEV1_lower` and
#'   `FEV1_upper` (95% prediction interval), and `Scenario`
#'   (`"Smoking"` or `"QuitsSmoking"`).
#'
#' @references
#' Zafari Z, Sin DD, Postma DS, et al. Individualized prediction of lung-function
#' decline in chronic obstructive pulmonary disease. *CMAJ.*
#' 2016;188(14):1004-1011. \doi{10.1503/cmaj.151483}
#'
#' @examples
#' model_run(get_default_input())
#' model_run(fev1_0 = 2.5, age = 70, height = 1.68, weight = 65,
#'           sex = "male", smoking = 1)
#' @export
model_run <- function(model_input = NULL, ...) {
  df <- .fev1_normalize(model_input, list(...))
  if (is.null(df)) df <- as.data.frame(get_default_input(), stringsAsFactors = FALSE)

  missing <- setdiff(.fev1_required, names(df))
  if (length(missing) > 0) {
    stop("Missing required variable(s): ", paste(missing, collapse = ", "),
         ". Accepted names (incl. aliases) are documented in ?model_run.",
         call. = FALSE)
  }
  df <- df[1, , drop = FALSE]

  height <- as.numeric(df$height)
  if (is.na(height) || height <= 0 || height > 3) {
    stop("`height` must be in metres (e.g. 1.68). Got: ", df$height,
         ". Values above 3 look like centimetres; convert before calling.",
         call. = FALSE)
  }

  patient <- data.frame(
    fev1_0     = as.numeric(df$fev1_0),
    int_effect = if (is.null(df$int_effect)) 0 else as.numeric(df$int_effect),
    male       = .fev1_male(df$male),
    smoking    = .fev1_smoking(df$smoking),
    age        = as.numeric(df$age),
    weight     = as.numeric(df$weight),
    height     = height,
    tio        = if (is.null(df$tio)) "No" else as.character(df$tio),
    stringsAsFactors = FALSE
  )

  pm <- if (is.null(df$prediction_model)) 3 else as.integer(df$prediction_model)
  if (!pm %in% 1:4) stop("`prediction_model` must be 1, 2, 3 or 4.", call. = FALSE)

  fev1::predictFEV1(patient, onePatient = TRUE, predictionModel = pm)
}

#' Example FEV1 input cohort
#'
#' @param n Optional positive integer; if supplied, the first `n` rows are
#'   returned. Defaults to all rows.
#' @param ... Additional fields supplied by the platform; ignored.
#' @return A data frame of example patients.
#' @seealso [model_run()], [get_default_input()]
#' @examples
#' get_sample_input()
#' @export
get_sample_input <- function(n = NULL, ...) {
  df <- data.frame(
    fev1_0     = c(2.5, 3.6, 1.9),
    age        = c(70, 42, 61),
    height     = c(1.68, 1.82, 1.60),
    weight     = c(65, 84, 72),
    male       = c(1, 0, 0),
    smoking    = c(1, 0, 1),
    int_effect = c(0, 0, 0),
    tio        = c("No", "Yes", "No"),
    stringsAsFactors = FALSE
  )
  if (!is.null(n)) {
    if (!is.numeric(n) || length(n) != 1L || n < 1L) {
      stop("`n` must be a single positive integer.", call. = FALSE)
    }
    df <- utils::head(df, n)
  }
  df
}

#' Default FEV1 input
#'
#' A 70-year-old male current smoker with a baseline FEV1 of 2.5 L — the
#' example patient shipped with the underlying `fev1` package.
#'
#' @param ... Additional fields supplied by the platform; ignored.
#' @return A named list of default predictor values.
#' @seealso [model_run()], [get_sample_input()]
#' @examples
#' get_default_input()
#' @export
get_default_input <- function(...) {
  list(
    fev1_0     = 2.5,
    age        = 70,
    height     = 1.68,
    weight     = 65,
    male       = 1,
    smoking    = 1,
    int_effect = 0,
    tio        = "No"
  )
}
