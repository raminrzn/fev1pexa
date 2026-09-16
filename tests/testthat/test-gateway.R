# The ModelsCloud platform dispatches to <pkg>::gateway(func = "model_run", ...).
test_that("gateway dispatches func='model_run' and returns JSON", {
  js <- gateway(func = "model_run", model_input = get_default_input())
  expect_type(js, "character")
  parsed <- jsonlite::fromJSON(js)
  expect_equal(nrow(parsed), 32L)
  expect_true(all(c("Year", "FEV1", "Scenario") %in% names(parsed)))
})

test_that("gateway defaults func to model_run and strips control fields", {
  js <- gateway(model_input = get_default_input(), api_key = "x",
                session_id = "y", execution_id = "z",
                callback_url = "https://example.invalid/cb")
  parsed <- jsonlite::fromJSON(js)
  expect_equal(parsed$FEV1, model_run(get_default_input())$FEV1, tolerance = 1e-12)
})

test_that("gateway with no input at all falls back to the default patient", {
  parsed <- jsonlite::fromJSON(gateway(execution_id = "z",
                                       callback_url = "https://example.invalid/cb"))
  expect_equal(nrow(parsed), 32L)
})

test_that("gateway preserves full numeric precision", {
  # jsonlite::toJSON() rounds to 4 significant digits by default, which would
  # flatten the projected trajectory into visibly wrong values.
  parsed <- jsonlite::fromJSON(gateway(func = "model_run",
                                       model_input = get_default_input()))
  expect_equal(parsed$FEV1[parsed$Scenario == "Smoking" & parsed$Year == 15],
               1.3639094769, tolerance = 1e-8)
})

test_that("gateway handles no-arg dispatch (get_default_input)", {
  parsed <- jsonlite::fromJSON(gateway(func = "get_default_input"))
  expect_true("fev1_0" %in% names(parsed))
})
