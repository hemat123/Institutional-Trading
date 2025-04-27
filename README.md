# app.py
import streamlit as st
import pandas as pd
import requests
import plotly.graph_objs as go
from datetime import datetime, timedelta
import pytz

# --- Function to get historical data ---
def get_binance_data(symbol, interval, limit):
    url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval={interval}&limit={limit}"
    response = requests.get(url)
    data = response.json()
    
    df = pd.DataFrame(data, columns=[
        'timestamp', 'open', 'high', 'low', 'close', 'volume',
        'close_time', 'quote_asset_volume', 'number_of_trades',
        'taker_buy_base', 'taker_buy_quote', 'ignore'
    ])
    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
    
    # Convert UTC to IST
    ist = pytz.timezone('Asia/Kolkata')
    df['timestamp'] = df['timestamp'].dt.tz_localize('UTC').dt.tz_convert(ist)
    
    df['open'] = df['open'].astype(float)
    df['high'] = df['high'].astype(float)
    df['low'] = df['low'].astype(float)
    df['close'] = df['close'].astype(float)
    
    return df

# --- Function to plot chart ---
def plot_chart(df):
    fig = go.Figure()

    fig.add_trace(go.Candlestick(
        x=df['timestamp'],
        open=df['open'],
        high=df['high'],
        low=df['low'],
        close=df['close'],
        name='Candles'
    ))

    # EMA 50
    df['EMA50'] = df['close'].ewm(span=50, adjust=False).mean()
    fig.add_trace(go.Scatter(
        x=df['timestamp'],
        y=df['EMA50'],
        line=dict(color='blue', width=1),
        name='EMA 50'
    ))

    # EMA 200
    df['EMA200'] = df['close'].ewm(span=200, adjust=False).mean()
    fig.add_trace(go.Scatter(
        x=df['timestamp'],
        y=df['EMA200'],
        line=dict(color='red', width=1),
        name='EMA 200'
    ))

    fig.update_layout(
        title="BTC/USDT Trading Chart",
        yaxis_title="Price",
        xaxis_title="Time (IST)",
        xaxis_rangeslider_visible=False,
        height=700
    )

    st.plotly_chart(fig, use_container_width=True)

# --- Streamlit Frontend ---
st.title("📈 BTC/USDT Trading Dashboard")

# Sidebar for options
st.sidebar.header("Settings")
timeframe_map = {
    "3 min": "3m",
    "5 min": "5m",
    "15 min": "15m",
    "30 min": "30m",
    "1 hour": "1h"
}
timeframe = st.sidebar.selectbox("Select Timeframe", list(timeframe_map.keys()))
limit = st.sidebar.slider("Number of Candles", min_value=50, max_value=1000, value=500, step=50)

# Button to Refresh
if st.sidebar.button("Generate Chart"):
    with st.spinner('Fetching data...'):
        df = get_binance_data('BTCUSDT', timeframe_map[timeframe], limit)
        plot_chart(df)
else:
    st.info("Select settings and click 'Generate Chart'.")

# Footer
st.markdown("---")
st.caption("🚀 Built by You!")
# Institutional-Trading
Trading signal indication
