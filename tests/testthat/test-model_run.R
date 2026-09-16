# Reference values come from calling resplab/fev1 directly with the same
# patient, so these tests catch the wrapper mangling inputs on the way through
# (unit confusion, sex/smoking miscoding, dropped optional fields) rather than
# re-testing the underlying model's arithmetic.

test_that("model_run reproduces fev1::predictFEV1 for the default patient", {
  out <- model_run(get_default_input())
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 32L)
  expect_setequal(unique(out$Scenario), c("Smoking", "QuitsSmoking"))

  smoke15 <- out$FEV1[out$Scenario == "Smoking" & out$Year == 15]
  quit15  <- out$FEV1[out$Scenario == "QuitsSmoking" & out$Year == 15]
  expect_equal(smoke15, 1.3639094769, tolerance = 1e-8)
  expect_equal(quit15,  1.8513494769, tolerance = 1e-8)

  # Quitting must never project worse lung function than continuing to smoke.
  expect_gt(quit15, smoke15)
})

test_that("both scenarios start at the observed baseline FEV1", {
  out <- model_run(get_default_input())
  expect_true(all(out$FEV1[out$Year == 0] == 2.5))
})

test_that("unwrapped args and aliases match the wrapped form", {
  wrapped <- model_run(list(fev1_0 = 2.5, age = 70, height = 1.68, weight = 65,
                            male = 1, smoking = 1))
  aliased <- model_run(fev1 = 2.5, age = 70, height = 1.68, weight = 65,
                       sex = "male", smoking = "current")
  expect_equal(wrapped$FEV1, aliased$FEV1)
})

test_that("height in centimetres is rejected rather than silently used", {
  # The model multiplies height and height^2 by large coefficients, so 168
  # would produce a confident, completely wrong trajectory.
  expect_error(
    model_run(fev1_0 = 2.5, age = 70, height = 168, weight = 65,
              male = 1, smoking = 1),
    "metres"
  )
})

test_that("sex and smoking accept labels as well as codes", {
  a <- model_run(fev1_0 = 3.6, age = 42, height = 1.82, weight = 84,
                 male = 0, smoking = 0)
  b <- model_run(fev1_0 = 3.6, age = 42, height = 1.82, weight = 84,
                 sex = "female", smoking = "former")
  expect_equal(a$FEV1, b$FEV1)
  expect_error(
    model_run(fev1_0 = 2.5, age = 70, height = 1.68, weight = 65,
              sex = "robot", smoking = 1),
    "Unrecognised"
  )
})

test_that("a JSON null is treated as an absent optional field", {
  expect_no_error(
    out <- model_run(list(fev1_0 = 2.5, age = 70, height = 1.68, weight = 65,
                          male = 1, smoking = 1,
                          int_effect = NULL, tio = NULL))
  )
  expect_equal(out$FEV1, model_run(get_default_input())$FEV1)
})

test_that("missing required predictors are named in the error", {
  expect_error(
    model_run(list(fev1_0 = 2.5, age = 70)),
    "Missing required variable"
  )
})

test_that("get_sample_input(n) limits rows and validates n", {
  expect_equal(nrow(get_sample_input(2)), 2L)
  expect_error(get_sample_input(0), "positive integer")
})
