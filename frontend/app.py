"""Start with: python -m streamlit run frontend/app.py."""

import os
from datetime import date
from html import escape
from pathlib import Path

import pandas as pd
import plotly.graph_objects as go
import requests
import streamlit as st
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")
API_URL = os.getenv("API_BASE_URL", "http://127.0.0.1:8000").rstrip("/")

st.set_page_config(page_title="Bikestores | Karar Destek", page_icon="🚲", layout="wide")
st.markdown(
    f"<style>{Path(__file__).with_name('styles.css').read_text(encoding='utf-8')}</style>",
    unsafe_allow_html=True,
)

MONTH_NAMES = [
    "", "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
    "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık",
]
LABELS = {
    "XGBoost": "XGBoost",
    "LightGBM": "LightGBM",
    "Last month": "Önceki ay",
    "3-month average": "Son 3 ay ortalaması",
    "Last year": "Geçen yıl aynı ay",
}
COLORS = {
    "XGBoost": "#2d67d3",
    "LightGBM": "#119b8d",
    "3-month average": "#e48b35",
    "Last month": "#8593a8",
    "Last year": "#a479be",
}


def month_label(value):
    value = pd.Timestamp(value)
    return f"{MONTH_NAMES[value.month]} {value.year}"


def api_request(path, payload=None, params=None):
    url = f"{API_URL}{path}"
    if payload is None:
        response = requests.get(url, params=params, timeout=(3, 30))
    else:
        response = requests.post(url, json=payload, timeout=(3, 30))
    response.raise_for_status()
    return response.json()


def api_error_text(error):
    response = getattr(error, "response", None)
    if response is not None:
        try:
            return response.json().get("detail", "Servis isteği tamamlanamadı.")
        except ValueError:
            pass
    return "Tahmin servisine bağlanılamadı. Backend'in çalıştığını kontrol edin."


def show_service_error(error, training_command):
    st.error(api_error_text(error))
    with st.expander("Başlatma komutları"):
        st.code(
            f"{training_command}\n"
            "python -m uvicorn backend.main:app --host 127.0.0.1 --port 8000",
            language="bash",
        )


def style_chart(fig, height=370, y_title="Satış adedi"):
    fig.update_layout(
        template="plotly_white",
        height=height,
        margin=dict(l=5, r=10, t=20, b=10),
        paper_bgcolor="#ffffff",
        plot_bgcolor="#ffffff",
        font=dict(family="Arial, sans-serif", color="#263b59", size=14),
        legend=dict(orientation="h", y=1.15, x=0),
        hovermode="x unified",
        xaxis_title=None,
        yaxis_title=y_title,
    )
    fig.update_xaxes(gridcolor="#edf1f6", linecolor="#b9c6d8", tickfont=dict(color="#405675"))
    fig.update_yaxes(
        gridcolor="#dce5f0",
        linecolor="#b9c6d8",
        tickfont=dict(color="#405675"),
        zeroline=False,
    )
    return fig


def render_demand_forecast(info):
    st.subheader("Gelecek ayın satış planı")
    st.caption("Mağaza ve kategori seçerek gelecek ayın tamamlanmış satış tahminini inceleyin.")

    store_names = {row["store_id"]: row["store_name"] for row in info["stores"]}
    category_names = {row["category_id"]: row["category_name"] for row in info["categories"]}
    supported_month = info["forecast_month"]

    with st.form("forecast_filters"):
        filter_columns = st.columns(3)
        store_id = filter_columns[0].selectbox(
            "Mağaza",
            [None, *store_names],
            format_func=lambda value: store_names.get(value, "Tüm mağazalar"),
        )
        category_id = filter_columns[1].selectbox(
            "Kategori",
            [None, *category_names],
            format_func=lambda value: category_names.get(value, "Tüm kategoriler"),
        )
        filter_columns[2].selectbox("Tahmin ayı", [supported_month], format_func=month_label)
        submitted = st.form_submit_button("Satış tahminini getir", type="primary")

    refresh = (
        "demand_forecast" not in st.session_state
        or st.session_state.get("demand_model_version") != info["model_version"]
        or submitted
    )
    if refresh:
        with st.spinner("Satış tahmini hazırlanıyor…"):
            try:
                st.session_state.demand_forecast = api_request(
                    "/forecast",
                    payload={
                        "month": supported_month,
                        "store_id": store_id,
                        "category_id": category_id,
                    },
                )
                st.session_state.demand_model_version = info["model_version"]
            except requests.RequestException as error:
                show_service_error(error, "python -m script.train")
                return

    forecast = st.session_state.demand_forecast
    active_store = forecast["store_id"]
    active_category = forecast["category_id"]
    scope = (
        f"{store_names.get(active_store, 'Tüm mağazalar')} · "
        f"{category_names.get(active_category, 'Tüm kategoriler')}"
    )
    st.markdown(
        f'<div class="snapshot-note">{escape(scope)} · Tarihsel veri: {month_label(info["data_end"])} sonuna kadar '
        f'· Tahmin: <b>{month_label(supported_month)}</b></div>',
        unsafe_allow_html=True,
    )

    forecast_tab, performance_tab, info_tab = st.tabs(
        ["Tahmin sonucu", "Model başarısı", "Veri ve model"]
    )

    with forecast_tab:
        summary = forecast["summary"]
        columns = st.columns(4)
        columns[0].metric(
            "Beklenen satış",
            f"{summary['forecast_units']:,.1f}",
            help="Seçilen kapsamın toplam tahmini, adet.",
        )
        columns[1].metric("Son ay satışı", f"{summary['last_month_units']:,.0f}")
        columns[2].metric("Son 3 ay ortalaması", f"{summary['three_month_average']:,.1f}")
        change = summary["change_pct"]
        columns[3].metric(
            "Son aya göre değişim",
            f"{change:+.1f}%" if change is not None else "Hesaplanamaz",
        )

        st.markdown("#### Satış geçmişi ve tahmin")
        history = pd.DataFrame(forecast["history"])
        history["month_start"] = pd.to_datetime(history["month_start"])
        fig = go.Figure()
        fig.add_scatter(
            x=history.month_start,
            y=history.units_sold,
            name="Gerçekleşen",
            mode="lines+markers",
            line=dict(color="#182d4e", width=3),
        )
        fig.add_scatter(
            x=[history.month_start.iloc[-1], pd.Timestamp(supported_month)],
            y=[history.units_sold.iloc[-1], summary["forecast_units"]],
            name="Model tahmini",
            mode="lines+markers",
            line=dict(color="#2d67d3", dash="dash", width=3),
            marker=dict(size=10),
        )
        fig.add_scatter(
            x=[pd.Timestamp(supported_month)],
            y=[summary["three_month_average"]],
            name="Son 3 ay ortalaması",
            mode="markers",
            marker=dict(color="#e48b35", size=11, symbol="diamond"),
        )
        st.plotly_chart(style_chart(fig), width="stretch", theme=None, key="forecast_chart")
        st.caption(
            "Tahmin tamamlanmış satış adedidir. Stok ihtiyacı veya karşılanamayan talep değildir."
        )

        st.markdown("#### Mağaza ve kategori bazında tahminler")
        rows = pd.DataFrame(forecast["rows"])
        table = rows[
            ["store_name", "category_name", "prediction", "Last month", "3-month average"]
        ].rename(
            columns={
                "store_name": "Mağaza",
                "category_name": "Kategori",
                "prediction": "Tahmin (adet)",
                "Last month": "Son ay",
                "3-month average": "Son 3 ay ort.",
            }
        )
        st.dataframe(
            table,
            hide_index=True,
            width="stretch",
            column_config={
                name: st.column_config.NumberColumn(format="%.1f")
                for name in ["Tahmin (adet)", "Son ay", "Son 3 ay ort."]
            },
        )
        st.download_button(
            "Tahminleri CSV indir",
            rows.to_csv(index=False).encode("utf-8-sig"),
            file_name=f"bikestores_forecast_{supported_month}.csv",
            mime="text/csv",
        )

    with performance_tab:
        st.markdown("#### Satış tahmini modelinin başarısı")
        st.info(
            f"Kullanılan model: **{info['selected_model']}** · Ana hata metriği: **MAE**"
        )
        period = st.radio(
            "Değerlendirme dönemi",
            ["test", "validation"],
            horizontal=True,
            format_func=lambda value: (
                "Test · Ocak–Mart 2018"
                if value == "test"
                else "Doğrulama · Temmuz–Aralık 2017"
            ),
        )
        try:
            performance = api_request(
                "/performance",
                params={
                    "period": period,
                    "store_id": active_store,
                    "category_id": active_category,
                },
            )
        except requests.RequestException as error:
            show_service_error(error, "python -m script.train")
            return

        scores = pd.DataFrame(performance["scores"])
        selected = scores[scores.model == performance["selected_model"]].iloc[0]
        cards = st.columns(4)
        cards[0].metric(
            "MAE · adet",
            f"{selected.mae:.2f}",
            help="Tahminlerin gerçek satıştan ortalama kaç adet saptığını gösterir. Düşük değer daha iyidir.",
        )
        cards[1].metric(
            "RMSE · adet",
            f"{selected.rmse:.2f}",
            help="Büyük tahmin hatalarına daha fazla ağırlık verir. Düşük değer daha iyidir.",
        )
        cards[2].metric(
            "WAPE",
            f"{selected.wape:.1f}%" if pd.notna(selected.wape) else "Hesaplanamaz",
            help="Toplam mutlak hatanın toplam satışa oranıdır. Düşük değer daha iyidir.",
        )
        cards[3].metric(
            "Sapma · adet",
            f"{selected.bias:+.2f}",
            help="Pozitif değer yüksek, negatif değer düşük tahmin eğilimini gösterir. Sıfıra yakın olması iyidir.",
        )
        st.caption(f"{scope} · {int(selected.rows)} tahmin")

        with st.expander("Metrikleri nasıl yorumlamalıyım?"):
            st.markdown(
                """
                - **MAE:** Ortalama tahmin hatasını satış adedi olarak verir.
                - **RMSE:** Büyük hataları daha güçlü cezalandırır.
                - **WAPE:** Hatayı toplam satış hacmine göre yüzde olarak gösterir.
                - **Sapma:** Modelin sürekli yüksek veya düşük tahmin yapıp yapmadığını gösterir.

                Model seçimi Temmuz–Aralık 2017 doğrulama döneminde yapılmıştır. Ocak–Mart 2018
                test dönemi, seçilen modelin daha sonraki aylardaki performansını gösterir.
                """
            )

        monthly = pd.DataFrame(performance["monthly"])
        monthly["month_start"] = pd.to_datetime(monthly.month_start)
        fig = go.Figure()
        fig.add_scatter(
            x=monthly.month_start,
            y=monthly.units_sold,
            name="Gerçekleşen",
            mode="lines+markers",
            line=dict(color="#182d4e", width=3),
        )
        for name in ["XGBoost", "LightGBM", "3-month average"]:
            fig.add_scatter(
                x=monthly.month_start,
                y=monthly[name],
                name=LABELS[name],
                mode="lines+markers",
                line=dict(color=COLORS[name], dash="dash"),
            )
        st.plotly_chart(style_chart(fig), width="stretch", theme=None, key="performance_chart")

        comparison = scores.drop(columns="rows").rename(
            columns={
                "model": "Model",
                "mae": "MAE",
                "rmse": "RMSE",
                "wape": "WAPE (%)",
                "bias": "Sapma",
            }
        )
        comparison["Model"] = comparison.Model.map(LABELS)
        st.dataframe(comparison, hide_index=True, width="stretch")

        left, right = st.columns(2)
        with left:
            st.markdown("**Mağaza bazında hata**")
            store_errors = pd.DataFrame(performance["errors"]["stores"])
            st.dataframe(
                store_errors[["store_name", "mae", "bias"]].rename(
                    columns={"store_name": "Mağaza", "mae": "MAE", "bias": "Sapma"}
                ),
                hide_index=True,
            )
        with right:
            st.markdown("**Kategori bazında hata**")
            category_errors = pd.DataFrame(performance["errors"]["categories"])
            st.dataframe(
                category_errors[["category_name", "mae", "bias"]].rename(
                    columns={"category_name": "Kategori", "mae": "MAE", "bias": "Sapma"}
                ),
                hide_index=True,
            )

    with info_tab:
        st.markdown("#### Veri ve model özeti")
        detail = pd.DataFrame(
            {
                "Bilgi": [
                    "Model", "Veri aralığı", "Tahmin ayı", "Eğitim zamanı (UTC)",
                    "Mağaza–kategori sayısı", "Aylık gözlem", "Model sürümü",
                ],
                "Değer": [
                    info["selected_model"],
                    f"{month_label(info['data_start'])} – {month_label(info['data_end'])}",
                    month_label(supported_month),
                    info["trained_at"][:19].replace("T", " "),
                    str(info["series_count"]),
                    str(info["history_rows"]),
                    info["model_version"],
                ],
            }
        )
        st.dataframe(detail, hide_index=True, width="stretch")
        st.markdown("**Model neye bakıyor?**")
        st.write(
            "Mağaza, kategori, takvim ayı; önceki 1, 2 ve 3 ayın satışları ile "
            "son 3 ve 6 ayın ortalamaları."
        )
        with st.expander("Teknik ayrıntılar"):
            st.json(
                {
                    "features": info["features"],
                    "versions": info["versions"],
                    "training_rows": info["training_rows"],
                }
            )


def risk_gauge(probability_pct, threshold_pct, risk_level):
    color = {"Düşük": "#1f9d72", "Orta": "#e49a24", "Yüksek": "#d94b5b"}[risk_level]
    fig = go.Figure(
        go.Indicator(
            mode="gauge+number",
            value=probability_pct,
            number={"suffix": "%", "font": {"size": 42, "color": "#10213d"}},
            title={"text": "Gecikme olasılığı", "font": {"size": 18, "color": "#53647d"}},
            gauge={
                "axis": {"range": [0, 100], "ticksuffix": "%"},
                "bar": {"color": color, "thickness": 0.35},
                "bgcolor": "#edf2f8",
                "borderwidth": 0,
                "steps": [
                    {"range": [0, threshold_pct], "color": "#def3e9"},
                    {"range": [threshold_pct, 50], "color": "#fff1d7"},
                    {"range": [50, 100], "color": "#fde4e7"},
                ],
                "threshold": {
                    "line": {"color": "#10213d", "width": 3},
                    "thickness": 0.75,
                    "value": threshold_pct,
                },
            },
        )
    )
    fig.update_layout(
        height=270,
        margin=dict(l=25, r=25, t=45, b=10),
        paper_bgcolor="#ffffff",
        font=dict(family="Arial, sans-serif"),
    )
    return fig


def render_shipment_model_success(info):
    evaluation = info.get("evaluation", {})
    st.markdown("#### Kargo gecikme modelinin başarısı")

    if not evaluation:
        st.caption("Başarı metriklerini görmek için güncel backend servisini yeniden başlatın.")
        return

    st.info(
        f"Kullanılan model: **{info['model_name']}** · Ana ayrıştırma metriği: **ROC-AUC**"
    )
    metrics = st.columns(3)
    metrics[0].metric(
        "ROC-AUC",
        f"{evaluation['roc_auc']:.3f}",
        help="Modelin geciken siparişleri diğerlerinden ayırma gücü. 0.5 rastgele, 1.0 kusursuz ayrım demektir.",
    )
    metrics[1].metric(
        "Recall",
        f"%{evaluation['recall'] * 100:.1f}",
        help="Gerçekte geciken siparişlerin ne kadarının uyarı aldığını gösterir.",
    )
    metrics[2].metric(
        "F1 skoru",
        f"{evaluation['f1']:.3f}",
        help="Precision ve recall değerlerinin dengeli birleşimidir. Yüksek değer daha iyidir.",
    )

    st.caption(
        f"Test dönemi: Ocak–Mart 2018 · PR-AUC: {evaluation['pr_auc']:.3f} · "
        f"Precision: %{evaluation['precision'] * 100:.1f} · F2: {evaluation['f2']:.3f} · "
        f"Karar eşiği: %{info['threshold'] * 100:.0f}"
    )
    with st.expander("Sınıflandırma metriklerini nasıl yorumlamalıyım?"):
        st.markdown(
            """
            - **ROC-AUC:** Modelin riskli siparişleri üst sıralara taşıma gücünü ölçer.
            - **PR-AUC:** Gecikme sınıfına odaklanan sıralama metriğidir; dengesiz sınıflarda yararlıdır.
            - **Recall:** Gerçekte geciken siparişleri yakalama oranıdır.
            - **Precision:** Uyarı verilen siparişlerin gerçekten gecikme oranıdır.
            - **F1:** Precision ve recall arasındaki dengeyi gösterir.
            - **F2:** Gecikmeleri kaçırmamaya daha fazla ağırlık verir.

            Testte recall %100, precision %44,8'dir. Model geçmiş test dönemindeki tüm gecikmeleri
            yakalamıştır; bunun karşılığında bazı zamanında siparişlere de uyarı vermiştir. Sonuçlar
            üç aylık tarihsel test dönemine aittir ve gelecekte aynı başarıyı garanti etmez.
            """
        )


def render_shipment_risk(info):
    st.subheader("Kargo gecikme riski")
    st.caption(
        "Yeni sipariş bilgilerini girin. Model gecikme olasılığını hesaplasın ve takip önerisi oluştursun."
    )
    render_shipment_model_success(info)
    st.divider()

    store_names = {row["store_id"]: row["store_name"] for row in info["stores"]}
    staff_rows = info["staff"]

    first_store = next(iter(store_names))
    first_staff = next(row["staff_id"] for row in staff_rows if row["store_id"] == first_store)
    defaults = {
        "shipment_store": first_store,
        "shipment_staff": first_staff,
        "shipment_order_date": date.today(),
        "shipment_lead_days": 3,
        "shipment_distinct_products": 2,
        "shipment_total_units": 5,
        "shipment_net_value": 1500.0,
        "shipment_discount": 5.0,
    }
    for key, value in defaults.items():
        st.session_state.setdefault(key, value)

    heading, sample_action = st.columns([2.2, 1])
    with heading:
        st.markdown("#### Sipariş bilgileri")
    with sample_action:
        sample_clicked = st.button(
            "🎲 Test siparişi doldur",
            key="random_test_order",
            width="stretch",
            disabled=info.get("test_sample_count", 0) == 0,
            help="Ocak–Mart 2018 test döneminden rastgele bir sipariş getirir.",
        )

    if sample_clicked:
        try:
            sample = api_request("/late-shipment/random-test-order")
        except requests.RequestException as error:
            show_service_error(error, "python -m script.late_shipment_train")
            return

        st.session_state.shipment_store = sample["store_id"]
        st.session_state.shipment_staff = sample["staff_id"]
        st.session_state.shipment_order_date = date.fromisoformat(sample["order_date"])
        st.session_state.shipment_lead_days = sample["required_lead_days"]
        st.session_state.shipment_distinct_products = sample["distinct_products"]
        st.session_state.shipment_total_units = sample["total_units"]
        st.session_state.shipment_net_value = sample["net_order_value"]
        st.session_state.shipment_discount = sample["effective_discount_pct"]
        st.session_state.shipment_test_sample = sample
        st.session_state.pop("shipment_result", None)
        st.session_state.pop("shipment_input", None)

    def clear_test_sample():
        st.session_state.pop("shipment_test_sample", None)

    input_panel, guide_panel = st.columns([1.45, 1], gap="large")
    with input_panel:
        first_row = st.columns(3)
        store_id = first_row[0].selectbox(
            "Mağaza",
            list(store_names),
            format_func=lambda value: store_names[value],
            key="shipment_store",
            on_change=clear_test_sample,
        )
        available_staff = {
            row["staff_id"]: row["staff_name"]
            for row in staff_rows
            if row["store_id"] == store_id
        }
        if st.session_state.shipment_staff not in available_staff:
            st.session_state.shipment_staff = next(iter(available_staff))
        staff_id = first_row[1].selectbox(
            "Satış personeli",
            list(available_staff),
            format_func=lambda value: available_staff[value],
            key="shipment_staff",
            on_change=clear_test_sample,
        )
        order_date = first_row[2].date_input(
            "Sipariş tarihi",
            key="shipment_order_date",
            on_change=clear_test_sample,
        )

        second_row = st.columns(3)
        lead_days = second_row[0].number_input(
            "Teslim için verilen gün",
            min_value=1,
            max_value=60,
            step=1,
            key="shipment_lead_days",
            on_change=clear_test_sample,
        )
        distinct_products = second_row[1].number_input(
            "Farklı ürün sayısı",
            min_value=1,
            step=1,
            key="shipment_distinct_products",
            on_change=clear_test_sample,
        )
        total_units = second_row[2].number_input(
            "Toplam ürün adedi",
            min_value=1,
            step=1,
            key="shipment_total_units",
            on_change=clear_test_sample,
        )

        third_row = st.columns(2)
        net_order_value = third_row[0].number_input(
            "Net sipariş tutarı ($)",
            min_value=0.0,
            step=100.0,
            key="shipment_net_value",
            on_change=clear_test_sample,
        )
        discount_pct = third_row[1].number_input(
            "Efektif indirim (%)",
            min_value=0.0,
            max_value=100.0,
            step=1.0,
            key="shipment_discount",
            on_change=clear_test_sample,
        )
        predict_clicked = st.button(
            "Gecikme riskini hesapla", type="primary", key="shipment_predict", width="stretch"
        )

    with guide_panel:
        st.markdown("#### Model hangi bilgileri kullanıyor?")
        st.markdown(
            """
            - Siparişin mağazası ve sorumlu personeli
            - Siparişin verildiği ay ve haftanın günü
            - Teslim için ayrılan gün sayısı
            - Ürün çeşidi, toplam adet, tutar ve indirim
            """
        )
        st.info(
            f"Model %{info['threshold'] * 100:.0f} ve üzerindeki olasılıkları gecikme uyarısı olarak işaretler."
        )
        if "shipment_test_sample" in st.session_state:
            sample = st.session_state.shipment_test_sample
            st.success(
                f"Test siparişi #{sample['order_id']} yüklendi. "
                "Tahmini çalıştırınca gerçek sonuçla karşılaştırılacak."
            )

    if predict_clicked:
        payload = {
            "order_date": order_date.isoformat(),
            "store_id": int(store_id),
            "staff_id": int(staff_id),
            "required_lead_days": int(lead_days),
            "distinct_products": int(distinct_products),
            "total_units": int(total_units),
            "net_order_value": float(net_order_value),
            "effective_discount_pct": float(discount_pct),
        }
        with st.spinner("Gecikme riski hesaplanıyor…"):
            try:
                st.session_state.shipment_result = api_request(
                    "/late-shipment/predict", payload=payload
                )
                st.session_state.shipment_input = payload
            except requests.RequestException as error:
                show_service_error(error, "python -m script.late_shipment_train")
                return

    if "shipment_result" not in st.session_state:
        st.markdown(
            '<div class="empty-state"><b>Sonuç burada görünecek.</b><br>'
            'Sipariş bilgilerini tamamlayıp “Gecikme riskini hesapla” düğmesine basın.</div>',
            unsafe_allow_html=True,
        )
        return

    result = st.session_state.shipment_result
    saved_input = st.session_state.shipment_input
    risk_class = {"Düşük": "risk-low", "Orta": "risk-medium", "Yüksek": "risk-high"}[
        result["risk_level"]
    ]
    st.markdown("---")
    st.markdown(
        f'<div class="risk-banner {risk_class}">'
        f'<div><span>RİSK DÜZEYİ</span><strong>{result["risk_level"]}</strong></div>'
        f'<p>Model tahmini: <b>{result["prediction"]}</b></p></div>',
        unsafe_allow_html=True,
    )

    chart_column, result_column = st.columns([1, 1.25], gap="large")
    with chart_column:
        st.plotly_chart(
            risk_gauge(
                result["late_probability_pct"],
                result["decision_threshold"] * 100,
                result["risk_level"],
            ),
            width="stretch",
            theme=None,
            key="shipment_risk_gauge",
        )
    with result_column:
        st.markdown("#### Önerilen aksiyon")
        st.markdown(f'**{result["recommendation"]["title"]}**')
        for action in result["recommendation"]["actions"]:
            st.markdown(f"- {action}")
        st.caption(
            "Bu öneriler operasyonel takip içindir. Model sonucu kesin bir teslimat sonucu değildir."
        )

    metrics = st.columns(3)
    metrics[0].metric("Gecikme olasılığı", f"%{result['late_probability_pct']:.1f}")
    metrics[1].metric("Sınıf tahmini", result["prediction"])
    metrics[2].metric("Karar eşiği", f"%{result['decision_threshold'] * 100:.0f}")

    if "shipment_test_sample" in st.session_state:
        sample = st.session_state.shipment_test_sample
        actual_late = bool(sample["actual_is_late"])
        actual_text = "Gecikti" if actual_late else "Zamanında gönderildi"
        if result["predicted_late"] == actual_late:
            st.success(f"Test setindeki gerçek sonuç: **{actual_text}** · Model sınıfı doğru.")
        else:
            st.warning(f"Test setindeki gerçek sonuç: **{actual_text}** · Model sınıfı farklı.")

    with st.expander("Tahmin girdileri ve model bilgisi"):
        st.json(
            {
                "sipariş": {
                    "sipariş tarihi": saved_input["order_date"],
                    "mağaza": store_names[saved_input["store_id"]],
                    "personel": next(
                        row["staff_name"]
                        for row in staff_rows
                        if row["staff_id"] == saved_input["staff_id"]
                    ),
                    "teslim süresi (gün)": saved_input["required_lead_days"],
                    "farklı ürün": saved_input["distinct_products"],
                    "toplam adet": saved_input["total_units"],
                    "net tutar": saved_input["net_order_value"],
                    "indirim (%)": saved_input["effective_discount_pct"],
                },
                "model": result["model_name"],
            }
        )


try:
    demand_info = api_request("/model-info")
    demand_error = None
except requests.RequestException as error:
    demand_info = None
    demand_error = error

try:
    shipment_info = api_request("/late-shipment/model-info")
    shipment_error = None
except requests.RequestException as error:
    shipment_info = None
    shipment_error = error

with st.sidebar:
    st.title("BIKESTORES")
    st.caption("KARAR DESTEK PANELİ")
    st.divider()
    st.markdown("**ML servisleri**")
    st.caption("● Satış tahmini hazır" if demand_info else "○ Satış tahmini hazır değil")
    st.caption("● Kargo riski hazır" if shipment_info else "○ Kargo riski hazır değil")
    st.divider()
    st.caption(f"API: {API_URL}")

st.markdown('<div class="eyebrow">BIKESTORES ANALYTICS</div>', unsafe_allow_html=True)
st.title("Satış ve sevkiyat karar desteği")
st.caption("İki makine öğrenmesi modelini aynı panelden kullanın.")

demand_tab, shipment_tab = st.tabs(["📈 Satış tahmini", "📦 Kargo gecikme riski"])

with demand_tab:
    if demand_info is None:
        show_service_error(demand_error, "python -m script.train")
    else:
        render_demand_forecast(demand_info)

with shipment_tab:
    if shipment_info is None:
        show_service_error(shipment_error, "python -m script.late_shipment_train")
    else:
        render_shipment_risk(shipment_info)
