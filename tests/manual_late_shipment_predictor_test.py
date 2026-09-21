import pandas as pd

from script.late_shipment_predictor import (
    LateShipmentPredictor,
)


# ---------------------------------------------------------
# 1. Load predictor
# ---------------------------------------------------------

predictor = LateShipmentPredictor()

print("\n--- MODEL INFO ---")
print("Model:", predictor.model_name)
print("Threshold:", predictor.threshold)


# ---------------------------------------------------------
# 2. Store mapping
# ---------------------------------------------------------

store_options = (
    predictor.get_store_options()
)

print("\n--- STORES ---")
print(store_options)

assert store_options, (
    "Store reference data is empty."
)


# ---------------------------------------------------------
# 3. Staff mapping
# ---------------------------------------------------------

for store_name, store_id in (
    store_options.items()
):

    staff_options = (
        predictor.get_staff_options(
            store_id=store_id
        )
    )

    print(
        f"\n--- STAFF | "
        f"{store_name} ---"
    )

    print(
        staff_options
    )

    assert staff_options, (
        f"No staff found for "
        f"{store_name}."
    )


# ---------------------------------------------------------
# 4. Select one valid store-staff pair
# ---------------------------------------------------------

selected_store_name = next(
    iter(store_options)
)

selected_store_id = (
    store_options[
        selected_store_name
    ]
)

staff_options = (
    predictor.get_staff_options(
        store_id=selected_store_id
    )
)

selected_staff_name = next(
    iter(staff_options)
)

selected_staff_id = (
    staff_options[
        selected_staff_name
    ]
)

print("\n--- SELECTED PAIR ---")

print(
    "Store:",
    selected_store_name,
    "| ID:",
    selected_store_id,
)

print(
    "Staff:",
    selected_staff_name,
    "| ID:",
    selected_staff_id,
)


# ---------------------------------------------------------
# 5. Test reverse mapping
# ---------------------------------------------------------

assert (
    predictor.get_store_name(
        selected_store_id
    )
    == selected_store_name
)

assert (
    predictor.get_staff_name(
        selected_staff_id
    )
    == selected_staff_name
)

print(
    "\nReverse mapping: OK"
)


# ---------------------------------------------------------
# 6. Prediction with required_date
# ---------------------------------------------------------

sample_order = pd.DataFrame(
    [
        {
            "order_date":
                "2018-04-10",

            "required_date":
                "2018-04-11",

            "store_id":
                selected_store_id,

            "staff_id":
                selected_staff_id,

            "distinct_products":
                3,

            "total_units":
                5,

            "net_order_value":
                4500.00,

            "effective_discount_pct":
                10.00,
        }
    ]
)

prediction = predictor.predict(
    sample_order
)

print(
    "\n--- PREDICTION "
    "WITH REQUIRED DATE ---"
)

print(
    prediction.T
)


# ---------------------------------------------------------
# 7. Validate prediction output
# ---------------------------------------------------------

expected_columns = [
    "late_probability",
    "late_probability_pct",
    "predicted_late",
    "risk_alert",
    "decision_threshold",
]

for column in expected_columns:

    assert column in prediction.columns, (
        f"Missing prediction column: "
        f"{column}"
    )


probability = prediction.loc[
    0,
    "late_probability",
]

assert 0 <= probability <= 1

assert (
    prediction.loc[
        0,
        "decision_threshold"
    ]
    == predictor.threshold
)

print(
    "\nPrediction output: OK"
)


# ---------------------------------------------------------
# 8. Prediction with required_lead_days
# ---------------------------------------------------------

sample_order_with_lead = (
    pd.DataFrame(
        [
            {
                "order_date":
                    "2018-04-10",

                "required_lead_days":
                    3,

                "store_id":
                    selected_store_id,

                "staff_id":
                    selected_staff_id,

                "distinct_products":
                    3,

                "total_units":
                    5,

                "net_order_value":
                    4500.00,

                "effective_discount_pct":
                    10.00,
            }
        ]
    )
)

prediction_with_lead = (
    predictor.predict(
        sample_order_with_lead
    )
)

print(
    "\n--- PREDICTION "
    "WITH LEAD DAYS ---"
)

print(
    prediction_with_lead.T
)


# ---------------------------------------------------------
# 9. Compare lead-time effect
# ---------------------------------------------------------

one_day_probability = (
    prediction.loc[
        0,
        "late_probability"
    ]
)

three_day_probability = (
    prediction_with_lead.loc[
        0,
        "late_probability"
    ]
)

print(
    "\n--- LEAD TIME COMPARISON ---"
)

print(
    f"1-day lead probability: "
    f"{one_day_probability:.4f}"
)

print(
    f"3-day lead probability: "
    f"{three_day_probability:.4f}"
)


# ---------------------------------------------------------
# 10. Invalid store-staff pair
# ---------------------------------------------------------

other_store_ids = [
    store_id
    for store_id
    in store_options.values()
    if store_id
    != selected_store_id
]

if other_store_ids:

    wrong_store_id = (
        other_store_ids[0]
    )

    invalid_order = (
        sample_order.copy()
    )

    invalid_order[
        "store_id"
    ] = wrong_store_id

    try:

        predictor.predict(
            invalid_order
        )

        raise AssertionError(
            "Invalid store-staff pair "
            "was accepted."
        )

    except ValueError as error:

        print(
            "\n--- INVALID PAIR TEST ---"
        )

        print(
            "Expected error:",
            error
        )


print(
    "\nALL MANUAL TESTS PASSED."
)