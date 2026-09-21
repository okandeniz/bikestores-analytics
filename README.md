# BikeStores Analytics

## Türkçe

### Proje hakkında

BikeStores örnek verisi üzerinde SQL, Excel, Power BI ve iki makine öğrenmesi uygulamasını bir araya getiren karar destek projesi. MySQL görünümleri analiz ve model verisini hazırlar. FastAPI kayıtlı modellerden tahmin üretir; Streamlit tek panelde satış tahmini ve kargo gecikme riskini gösterir.

**Veri dönemi 2016–Mart 2018'dir.** Kayıtlı satış modeli, Mart 2018 sonundaki verilerle **Nisan 2018 için bir aylık** tahmin üretir. Bugünün veya gelecek 12 ayın tahminini üretmez. Sonuçlar kaydedilmiş tamamlanmış satış adedidir; karşılanamayan talep ya da doğrudan stok sipariş miktarı değildir.

### Proje yapısı

| Konum | İçerik |
| --- | --- |
| `sql/01_loading _data/` | MySQL için uyarlanmış örnek veritabanı şeması ve veri yükleme dosyaları. Klasör adındaki boşluk gerçektir. |
| `sql/02_data_quality/`, `sql/03_cleaning/`, `sql/04_views/`, `sql/05_analysis/` | Veri kalite kontrolleri, iş kuralları, analiz görünümleri ve SQL analizleri. |
| `sql/06_excel_exports/`, `sql/07_ml_outputs/` | Excel kaynak görünümleri ve Power BI için ML çıktı tabloları. |
| `src/` | Ortam ayarları, MySQL bağlantısı ve Excel veri aktarımı. |
| `notebooks/` | Satış tahmini ve kargo gecikmesi araştırma notebook'ları. |
| `script/` | Her iki modelin ortak özellikleri, eğitim, tahmin ve MySQL'e sonuç aktarımı. |
| `backend/main.py`, `frontend/app.py` | FastAPI servisi ve iki sekmeli Streamlit arayüzü. |
| `dashboards/BikeStoreAnalytics.pbix` | Yedi sayfalı Power BI raporu. |
| `excel_analysis/BikeStores_Analytics.xlsx` | Analiz sayfaları içeren Excel çalışma kitabı. |
| `outputs/`, `models/` | Üretilmiş veri/raporlar ve model bilgileri. `.joblib` modelleri Git'e eklenmez. |
| `tests/` | Tahmin ve API kontrolleri. |

### Kurulum

Komutları proje kökünde çalıştırın. Python ve MySQL gereklidir. Windows PowerShell örneği:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-lock.txt
Copy-Item .env.example .env
```

Mevcut `.env` dosyanız varsa kopyalama komutunu çalıştırmayın. `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` alanlarını kendi MySQL ayarlarınıza göre doldurun. `MODEL_PATH`, `LATE_SHIPMENT_MODEL_PATH` ve `API_BASE_URL` isteğe bağlıdır. `.env` ve model paketleri `.gitignore` kapsamındadır. Kilit dosyası Python paket sürümlerini sabitler; eğitim ve servis için aynı ortamı kullanın. Eski bir `.venv` başka bir Python konumuna bağlıysa yeni bir ortam oluşturun.

### Veritabanı ve modeller

1. `sql/01_loading _data/` içindeki **create objects**, ardından **load data** SQL dosyalarını MySQL'de çalıştırın.
2. `sql/04_views/` ve `sql/06_excel_exports/` dosyalarını numara sırasıyla çalıştırın. Eğitim için `vw_excel_order_items` ve `vw_excel_orders` gereklidir.
3. Power BI model çıktılarını kullanacaksanız `sql/07_ml_outputs/` içindeki iki tablo oluşturma dosyasını çalıştırın.
4. Modelleri eğitin:

```powershell
.\.venv\Scripts\python.exe -m script.train
.\.venv\Scripts\python.exe -m script.late_shipment_train
```

Eğitim `models/demand_forecast.joblib` ve `models/late_shipment_risk.joblib` dosyalarını oluşturur. GitHub'dan yeni klonlanan projede bu paketler bulunmaz; veritabanını hazırlayıp modelleri yeniden eğitmek gerekir. Satış verisi yeni bir tamamlanmış aya uzanıyorsa `.\.venv\Scripts\python.exe -m script.train --end-month YYYY-MM` komutunu kullanın ve API'yi yeniden başlatın. Kargo eğitimi halen kodda tanımlı 2016–Mart 2018 dönemiyle sınırlıdır.

### API ve arayüz

İki ayrı terminalde:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

```powershell
.\.venv\Scripts\python.exe -m streamlit run frontend/app.py --server.port 8501
```

Arayüz: <http://127.0.0.1:8501> · API belgesi: <http://127.0.0.1:8000/docs>. Port 8000 doluysa API'yi başka portta başlatın ve `.env` içindeki `API_BASE_URL` değerini aynı porta ayarlayın. Model dosyaları eksikse ilgili uç noktalar 503 döndürür.

| Uç nokta | İşlev |
| --- | --- |
| `GET /health` | İki modelin yüklenme durumu. |
| `GET /model-info`, `POST /forecast`, `GET /performance` | Satış modeli bilgisi, bir aylık tahmin ve geçmiş performans. |
| `GET /late-shipment/model-info`, `POST /late-shipment/predict` | Gecikme modeli bilgisi ve sipariş riski/öneri. |
| `GET /late-shipment/random-test-order` | Tarihsel örnek siparişle formu doldurma. |

Arayüzde satış tahmini filtreleri, geçmiş performans, gecikme olasılığı ve operasyon önerileri bulunur. Satış modeli 2017 doğrulamasında yöntem seçer; Ocak–Mart 2018 geçmiş testinde MAE, RMSE, WAPE ve sapma gösterir. Kayıtlı model bilgisinde seçilen yöntem XGBoost'tur; test WAPE yaklaşık **%42,2**'dir. Kargo modeli lojistik regresyon ve **0,20** karar eşiği kullanır; kayıtlı model bilgisindeki ROC-AUC **0,800**, PR-AUC **0,559** değerleri notebook değerlendirmesinden aktarılmıştır.

**Değerlendirme sınırı:** Kargo üretim modeli son aşamada tüm tarihsel verilerle, test dönemi dahil, yeniden eğitilir. Rastgele örnek butonundaki siparişler de bu verinin içindedir. Bu butondaki anlık tahminleri bağımsız test başarısı olarak yorumlamayın. Power BI'ya aktarılan bu sipariş tahminleri de son model için eğitim içi sonuçlardır; metadata'daki test metrikleri ise önceki notebook değerlendirmesine aittir.

### Excel ve Power BI

Excel veri dosyasını yeniden üretmek için `.\.venv\Scripts\python.exe -m src.excel_export` çalıştırın. Çıktı `outputs/excel/BikeStores_Data.xlsx` konumundadır ve `Data_OrderItems`, `Data_Orders`, `Data_Inventory` sayfalarını içerir. `excel_analysis/BikeStores_Analytics.xlsx` ayrıca yönetici özeti, mağaza, personel, ürün, indirim, operasyon ve stok analiz sayfaları içerir.

Power BI için model sonuçlarını MySQL'e aktarın:

```powershell
.\.venv\Scripts\python.exe -m script.demand_forecast_export
.\.venv\Scripts\python.exe -m script.late_shipment_export
```

İlk komut `ml_demand_forecast` ve `ml_demand_model_scores`; ikincisi `ml_late_shipment_predictions` ve `ml_late_shipment_model_metrics` tablolarını doldurur. `dashboards/BikeStoreAnalytics.pbix` içinde Executive Overview, Sales Performance, Store & Staff, Product & Category, Inventory & Stock, Demand Forecasting ve Late Shipment Risk sayfaları vardır. Raporu Power BI Desktop'ta açtığınızda veri kaynağı/kimlik bilgilerini kendi MySQL ortamınıza göre kontrol edin ve veriyi yenileyin. PBIX içe aktarılmış veri modeli içerebilir; yayımlamadan önce raporun içindeki verileri gözden geçirin.

### GitHub öncesi kontrol

- `.env` dosyasını, gerçek parolaları ve güvenilmeyen `.joblib` dosyalarını paylaşmayın. `joblib.load` yalnızca güvenilir model paketleriyle kullanılmalıdır.
- Notebook çıktıları, CSV/Excel dosyaları ve PBIX raporu örnek sipariş, müşteri veya personel verisi içerebilir. Bunları herkese açık repoya koymadan önce içeriklerini inceleyin.
- API kimlik doğrulama veya hız sınırı uygulamıyor. Varsayılan `127.0.0.1` bağlaması yalnızca yerel kullanım içindir; internete açmadan önce erişim denetimi ekleyin.
- Kontroller: `python -m unittest discover -s tests -v`, `git status --short`, `git check-ignore -v .env`.

## English

### About the project

BikeStores Analytics combines SQL, Excel, Power BI, and two machine learning workflows. MySQL views prepare the data. FastAPI serves saved models, and one Streamlit app shows sales forecasts and late-shipment risk.

**The data ends in March 2018.** The saved sales model uses data available through March 2018 to forecast **one month ahead: April 2018**. It does not predict today's sales or the next 12 months. Its target is recorded completed sales in units, not unmet demand or a direct stock order quantity.

### Repository map

| Location | Purpose |
| --- | --- |
| `sql/01_loading _data/` | MySQL sample database schema and data loading scripts. The space in the directory name is intentional. |
| `sql/02_data_quality/`, `sql/03_cleaning/`, `sql/04_views/`, `sql/05_analysis/` | Data checks, business rules, views, and analysis queries. |
| `sql/06_excel_exports/`, `sql/07_ml_outputs/` | Excel source views and tables for ML results used by Power BI. |
| `src/` | Configuration, MySQL connection, and Excel export. |
| `notebooks/` | Research notebooks for the two models. |
| `script/` | Feature logic, training, prediction, and SQL exports. |
| `backend/main.py`, `frontend/app.py` | FastAPI service and two-tab Streamlit app. |
| `dashboards/BikeStoreAnalytics.pbix` | Seven-page Power BI report. |
| `excel_analysis/BikeStores_Analytics.xlsx` | Excel analysis workbook. |
| `outputs/`, `models/` | Generated reports/data and model metadata. `.joblib` files are ignored by Git. |
| `tests/` | Forecast and API checks. |

### Setup

Run commands from the repository root. Python and MySQL are required. On Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-lock.txt
Copy-Item .env.example .env
```

Do not copy over an existing `.env`. Set `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME` for your MySQL server. `MODEL_PATH`, `LATE_SHIPMENT_MODEL_PATH`, and `API_BASE_URL` are optional. Git ignores `.env` and model bundles. Use the same package environment for training and serving. Recreate an old virtual environment if it points to a Python installation that no longer exists.

### Database and training

1. Run the **create objects** and then **load data** scripts in `sql/01_loading _data/` against MySQL.
2. Run the scripts in `sql/04_views/` and `sql/06_excel_exports/` in numeric order. Training needs `vw_excel_order_items` and `vw_excel_orders`.
3. If you need Power BI model results, create both tables from `sql/07_ml_outputs/`.
4. Train and save both models:

```powershell
.\.venv\Scripts\python.exe -m script.train
.\.venv\Scripts\python.exe -m script.late_shipment_train
```

Training creates `models/demand_forecast.joblib` and `models/late_shipment_risk.joblib`. A fresh GitHub clone does not contain these files; prepare MySQL and train the models first. For a new fully completed sales month, run `.\.venv\Scripts\python.exe -m script.train --end-month YYYY-MM` and restart the API. The late-shipment training period is currently fixed in code to 2016–March 2018.

### Run the app

Start each command in a separate terminal:

```powershell
.\.venv\Scripts\python.exe -m uvicorn backend.main:app --host 127.0.0.1 --port 8000
```

```powershell
.\.venv\Scripts\python.exe -m streamlit run frontend/app.py --server.port 8501
```

App: <http://127.0.0.1:8501> · API docs: <http://127.0.0.1:8000/docs>. If port 8000 is busy, choose another API port and set `API_BASE_URL` in `.env` to match. An endpoint returns 503 when its model is missing.

| Endpoint | Purpose |
| --- | --- |
| `GET /health` | Loading status of both models. |
| `GET /model-info`, `POST /forecast`, `GET /performance` | Sales model information, one-month forecast, and historical scores. |
| `GET /late-shipment/model-info`, `POST /late-shipment/predict` | Shipment model information, risk score, and operational advice. |
| `GET /late-shipment/random-test-order` | Fill the form with a historical example order. |

The sales workflow selects a method on 2017 validation data and shows MAE, RMSE, WAPE, and bias for the January–March 2018 historical test. The saved model metadata names XGBoost as the selected method; its test WAPE is about **42.2%**. The shipment model uses logistic regression with a **0.20** decision threshold. Its saved metadata reports **0.800 ROC-AUC** and **0.559 PR-AUC** from an earlier notebook evaluation.

**Evaluation limit:** The final shipment model is refitted on all historical orders, including the historical test period. Orders returned by the random-example button are part of that training data. Their live predictions are therefore not independent test results. The order predictions exported to Power BI are also in-sample for the final model; the saved test metrics come from the earlier notebook evaluation.

### Excel and Power BI

Run `.\.venv\Scripts\python.exe -m src.excel_export` to recreate `outputs/excel/BikeStores_Data.xlsx`, with `Data_OrderItems`, `Data_Orders`, and `Data_Inventory` sheets. `excel_analysis/BikeStores_Analytics.xlsx` adds executive, store, staff, product, discount, operations, and inventory analysis sheets.

To send model outputs to MySQL for Power BI:

```powershell
.\.venv\Scripts\python.exe -m script.demand_forecast_export
.\.venv\Scripts\python.exe -m script.late_shipment_export
```

The first export fills `ml_demand_forecast` and `ml_demand_model_scores`. The second fills `ml_late_shipment_predictions` and `ml_late_shipment_model_metrics`. `dashboards/BikeStoreAnalytics.pbix` has Executive Overview, Sales Performance, Store & Staff, Product & Category, Inventory & Stock, Demand Forecasting, and Late Shipment Risk pages. In Power BI Desktop, check the report's data-source credentials and refresh against your own MySQL instance. A PBIX file can contain imported data, so review its contents before publishing it.

### Before publishing to GitHub

- Do not publish `.env`, real passwords, or untrusted `.joblib` bundles. Only load trusted model files with `joblib.load`.
- Notebook outputs, CSV/Excel files, and the PBIX report can contain order, customer, or staff data. Review them before making the repository public.
- The API has no authentication or rate limiting. Its default `127.0.0.1` binding is for local use; add access control before exposing it to the internet.
- Checks: `python -m unittest discover -s tests -v`, `git status --short`, and `git check-ignore -v .env`.
