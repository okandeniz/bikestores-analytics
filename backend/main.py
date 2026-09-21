"""Start with: python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000."""

import logging
import os
from contextlib import asynccontextmanager
from datetime import date
from pathlib import Path
from typing import Annotated, Literal

import pandas as pd
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from script.common import DEFAULT_MODEL_PATH, PROJECT_ROOT
from script.late_shipment_predictor import (
    DEFAULT_MODEL_PATH as DEFAULT_LATE_SHIPMENT_MODEL_PATH,
    LateShipmentPredictor,
)
from script.predictor import ForecastPredictor

load_dotenv(PROJECT_ROOT / ".env")
logger = logging.getLogger(__name__)


class ForecastRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    month: date | None = None
    store_id: int | None = Field(default=None, gt=0, strict=True)
    category_id: int | None = Field(default=None, gt=0, strict=True)


class LateShipmentRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    order_date: date
    store_id: int = Field(gt=0, strict=True)
    staff_id: int = Field(gt=0, strict=True)
    required_lead_days: int = Field(gt=0, le=60, strict=True)
    distinct_products: int = Field(gt=0, strict=True)
    total_units: int = Field(gt=0, strict=True)
    net_order_value: float = Field(ge=0)
    effective_discount_pct: float = Field(ge=0, le=100)


def shipment_recommendation(probability, threshold, lead_days):
    """Turn a probability into a short, practical operations checklist."""
    if probability >= 0.50:
        level = "Yüksek"
        title = "Siparişi öncelikli incelemeye alın"
        actions = [
            "Stok uygunluğunu ve ürün toplama durumunu bugün doğrulayın.",
            "Sevkiyat ekibiyle çıkış zamanını netleştirin.",
            "Gerekirse müşteriye alternatif teslim tarihi hazırlayın.",
        ]
    elif probability >= threshold:
        level = "Orta"
        title = "Siparişi yakından takip edin"
        actions = [
            "Stok ve ürün toplama durumunu sevkiyattan önce kontrol edin.",
            "Planlanan çıkış tarihini günlük takip listesine ekleyin.",
        ]
    else:
        level = "Düşük"
        title = "Standart sevkiyat akışını sürdürün"
        actions = [
            "Planlanan çıkış tarihini rutin kontrol listesinde izleyin.",
            "Stok veya operasyon durumu değişirse tahmini yenileyin.",
        ]

    if lead_days <= 2:
        actions.append("Teslim süresi kısa olduğu için ek kaynak veya yeni teslim tarihi değerlendirin.")

    return {"risk_level": level, "title": title, "actions": actions}


def create_app(model_path=None, late_model_path=None):
    demand_path = Path(model_path or os.getenv("MODEL_PATH", str(DEFAULT_MODEL_PATH)))
    shipment_path = Path(
        late_model_path
        or os.getenv("LATE_SHIPMENT_MODEL_PATH", str(DEFAULT_LATE_SHIPMENT_MODEL_PATH))
    )
    if not demand_path.is_absolute():
        demand_path = PROJECT_ROOT / demand_path
    if not shipment_path.is_absolute():
        shipment_path = PROJECT_ROOT / shipment_path

    @asynccontextmanager
    async def lifespan(app):
        app.state.forecast_predictor = None
        app.state.shipment_predictor = None

        try:
            app.state.forecast_predictor = ForecastPredictor(demand_path)
        except FileNotFoundError:
            logger.warning("No demand model. Run python -m script.train, then restart the API.")
        except Exception:
            logger.exception("The demand model could not be loaded.")

        try:
            app.state.shipment_predictor = LateShipmentPredictor(shipment_path)
        except FileNotFoundError:
            logger.warning(
                "No shipment model. Run python -m script.late_shipment_train, then restart the API."
            )
        except Exception:
            logger.exception("The late shipment model could not be loaded.")
        yield

    app = FastAPI(
        title="Bikestores Decision Support API",
        version="2.0.0",
        lifespan=lifespan,
        description="Sales forecasts and late-shipment risk predictions from saved models.",
    )

    def demand_service(request):
        predictor = request.app.state.forecast_predictor
        if predictor is None:
            raise HTTPException(
                503, "Demand model unavailable. Run python -m script.train and restart the API."
            )
        return predictor

    def shipment_service(request):
        predictor = request.app.state.shipment_predictor
        if predictor is None:
            raise HTTPException(
                503,
                "Shipment model unavailable. Run python -m script.late_shipment_train and restart the API.",
            )
        return predictor

    @app.get("/health", tags=["Status"])
    def health(request: Request):
        demand = request.app.state.forecast_predictor
        shipment = request.app.state.shipment_predictor
        ready = demand is not None and shipment is not None
        content = {
            "status": "ok" if ready else "not_ready",
            "model_loaded": demand is not None,
            "late_shipment_model_loaded": shipment is not None,
        }
        if demand is not None:
            content["model_version"] = demand.metadata["model_version"]
        if shipment is not None:
            content["late_shipment_model"] = shipment.model_name
        if ready:
            return content
        return JSONResponse(status_code=503, content=content)

    @app.get("/model-info", tags=["Demand forecast"])
    def model_info(request: Request):
        return demand_service(request).model_info()

    @app.post("/forecast", tags=["Demand forecast"])
    def forecast(body: ForecastRequest, request: Request):
        try:
            return demand_service(request).forecast(body.month, body.store_id, body.category_id)
        except ValueError as error:
            raise HTTPException(422, str(error)) from error

    @app.get("/performance", tags=["Demand forecast"])
    def performance(
        request: Request,
        period: Literal["test", "validation"] = "test",
        store_id: Annotated[int | None, Query(gt=0)] = None,
        category_id: Annotated[int | None, Query(gt=0)] = None,
    ):
        try:
            return demand_service(request).performance(period, store_id, category_id)
        except ValueError as error:
            raise HTTPException(422, str(error)) from error

    @app.get("/late-shipment/model-info", tags=["Late shipment"])
    def late_shipment_model_info(request: Request):
        predictor = shipment_service(request)
        return {
            "model_name": predictor.model_name,
            "threshold": predictor.threshold,
            "features": predictor.model_features,
            "stores": predictor.reference_data["stores"],
            "staff": predictor.reference_data["staff"],
            "test_sample_count": len(predictor.test_samples),
            "evaluation": predictor.metadata.get("evaluation", {}),
            "training_rows": predictor.metadata.get("training_rows"),
            "training_start": predictor.metadata.get("training_start"),
            "training_end": predictor.metadata.get("training_end"),
            "training_late_rate": predictor.metadata.get("training_late_rate"),
        }

    @app.get("/late-shipment/random-test-order", tags=["Late shipment"])
    def random_late_shipment_test_order(request: Request):
        try:
            return shipment_service(request).get_random_test_sample()
        except ValueError as error:
            raise HTTPException(404, str(error)) from error

    @app.post("/late-shipment/predict", tags=["Late shipment"])
    def late_shipment_predict(body: LateShipmentRequest, request: Request):
        predictor = shipment_service(request)
        order = pd.DataFrame([body.model_dump()])
        try:
            result = predictor.predict(order).iloc[0]
        except (TypeError, ValueError) as error:
            raise HTTPException(422, str(error)) from error

        probability = float(result["late_probability"])
        predicted_late = bool(result["predicted_late"])
        recommendation = shipment_recommendation(
            probability, predictor.threshold, body.required_lead_days
        )
        return {
            "late_probability": probability,
            "late_probability_pct": float(result["late_probability_pct"]),
            "predicted_late": predicted_late,
            "prediction": "Gecikebilir" if predicted_late else "Zamanında gönderilebilir",
            "decision_threshold": predictor.threshold,
            "risk_level": recommendation["risk_level"],
            "recommendation": {
                "title": recommendation["title"],
                "actions": recommendation["actions"],
            },
            "model_name": predictor.model_name,
        }

    return app


app = create_app()
