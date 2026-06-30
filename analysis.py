import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

sns.set_style('whitegrid')
plt.rcParams['figure.figsize'] = (10, 5)

clean = pd.read_csv('../data/clean_orders.csv')
rfm = pd.read_csv('../data/rfm_segments.csv')

print("Clean orders:", clean.shape)
print("RFM segments:", rfm.shape)
print(clean.head())

clean['invoice_date_ts'] = pd.to_datetime(clean['invoice_date_ts'])

monthly = clean.set_index('invoice_date_ts').resample('ME')['total_amount'].sum()

fig, ax = plt.subplots()
monthly.plot(ax=ax, marker='o', color='#1f77b4')
ax.set_title('Динамика продаж по месяцам')
ax.set_ylabel('Выручка, $')
plt.tight_layout()
plt.savefig('../images/monthly_trend.png', dpi=120)
plt.show()

print(monthly)
from scipy import stats

# Описательная статистика по сумме заказа
print("\n--- Описательная статистика total_amount ---")
print(clean['total_amount'].describe())

# Корреляция: количество товара vs сумма заказа
r, p = stats.pearsonr(clean['quantity'], clean['total_amount'])
print(f"\nКорреляция Quantity vs Total Amount: r = {r:.3f}, p-value = {p:.2e}")

fig, ax = plt.subplots()
sns.boxplot(x=clean['total_amount'], ax=ax)
ax.set_xlim(0, 200)  # обрезаем шкалу, чтобы не мешали огромные выбросы вроде $168k
ax.set_title('Распределение суммы заказов (без экстремальных выбросов)')
ax.set_xlabel('Сумма заказа, $')
plt.tight_layout()
plt.savefig('../images/total_amount_boxplot.png', dpi=120)
plt.close()

print("График сохранён")




segment_summary = rfm.groupby('segment').agg(
    customers=('customer_id', 'count'),
    avg_spent=('monetary', 'mean'),
    total_revenue=('monetary', 'sum')
).round(2).sort_values('total_revenue', ascending=False)

print("\n--- Сводка по сегментам ---")
print(segment_summary)

fig, axes = plt.subplots(1, 2, figsize=(13, 5))

segment_summary['customers'].plot(kind='bar', ax=axes[0], color='#2ca02c')
axes[0].set_title('Количество клиентов по сегментам')
axes[0].set_ylabel('Клиентов')

segment_summary['total_revenue'].plot(kind='bar', ax=axes[1], color='#1f77b4')
axes[1].set_title('Выручка по сегментам')
axes[1].set_ylabel('Выручка, $')

plt.tight_layout()
plt.savefig('../images/rfm_segments.png', dpi=120)
plt.close()

print("График сегментов сохранён")

top_products = clean.groupby(['stock_code', 'description']).agg(
    total_quantity=('quantity', 'sum'),
    revenue=('total_amount', 'sum')
).round(2).sort_values('revenue', ascending=False).head(10)

print("\n--- Топ-10 товаров по выручке ---")
print(top_products)

fig, ax = plt.subplots(figsize=(10, 6))
top_products['revenue'].sort_values().plot(kind='barh', ax=ax, color='#ff7f0e')
ax.set_title('Топ-10 товаров по выручке')
ax.set_xlabel('Выручка, $')
plt.tight_layout()
plt.savefig('../images/top_products.png', dpi=120)
plt.close()

print("График товаров сохранён")

top_countries = clean[clean['country'] != 'United Kingdom'].groupby('country').agg(
    orders=('invoice_no', 'nunique'),
    revenue=('total_amount', 'sum')
).round(2).sort_values('revenue', ascending=False).head(10)

print("\n--- Топ-10 стран по выручке (без UK) ---")
print(top_countries)

fig, ax = plt.subplots(figsize=(10, 6))
top_countries['revenue'].sort_values().plot(kind='barh', ax=ax, color='#9467bd')
ax.set_title('Топ-10 стран по выручке (без UK)')
ax.set_xlabel('Выручка, $')
plt.tight_layout()
plt.savefig('../images/top_countries.png', dpi=120)
plt.close()

print("График стран сохранён")


from scipy import stats

clean['z_amount'] = stats.zscore(clean['total_amount'])
outliers = clean[clean['z_amount'].abs() > 5].sort_values('z_amount', ascending=False)

print(f"\n--- Выбросы (Z-score > 5) ---")
print(f"Найдено {len(outliers)} аномальных строк из {len(clean)} ({len(outliers)/len(clean)*100:.2f}%)")
print(outliers[['invoice_no', 'description', 'quantity', 'unit_price', 'total_amount', 'country']].head(10))


pd.set_option('display.max_columns', None)
pd.set_option('display.width', None)

print("\n--- Топ-5 самых крупных выбросов (полная информация) ---")
print(outliers[['invoice_no', 'customer_id', 'description', 'quantity', 'unit_price', 'total_amount', 'country']].head(5))

# Создаём фиксированную версию rfm_segments для Power BI
rfm_fixed = rfm.copy()
rfm_fixed['monetary'] = rfm_fixed['monetary'].astype(str).str.replace('.', ',')
rfm_fixed.to_csv('../data/rfm_segments_fixed.csv', sep=';', index=False)
print("rfm_segments_fixed.csv готов!")




































































































































































































































































































































































