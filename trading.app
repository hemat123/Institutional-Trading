import streamlit as st
import pandas as pd
import ccxt
import plotly.graph_objs as go
import pytz
from datetime import datetime
import numpy as np

# ------------------------------------
# Streamlit page config
# ------------------------------------
st.set_page_config(page_title="BTC/USDT Institutional Trading", page_icon="📈", layout="wide")
st.title("📈 BTC/USDT Institutional Trading Dashboard")

# ------------------------------------
# Sidebar settings
# ------------------------------------
st.sidebar.header("Settings")

binance_timeframes = {
    "3 min": "3m",
    "5 min": "5m",
    "15 min": "15m",
    "30 min": "30m",
    "1 hour": "1h",
    "1 day": "1d",
}

selected_timeframe = st.sidebar.selectbox("Select Timeframe", list(binance_timeframes.keys()))
selected_binance_tf = binance_timeframes[selected_timeframe]

num_candles = st.sidebar.slider("Number of Candles", min_value=100, max_value=1000, value=350)

# ------------------------------------
# Functions
# ------------------------------------

def detect_support_resistance(df, window=20):
    """Detect support and resistance lines"""
    support = []
    resistance = []
    for i in range(window, len(df)-window):
        low = df['low'][i]
        high = df['high'][i]
        if low == min(df['low'][i-window:i+window]):
            support.append((df['timestamp'][i], low))
        if high == max(df['high'][i-window:i+window]):
            resistance.append((df['timestamp'][i], high))
    return support, resistance

def detect_liquidity_sweeps(df):
    """Detect possible liquidity sweeps (wicks that broke previous high/low)"""
    sweeps = []
    for i in range(1, len(df)):
        if df['high'][i] > df['high'][i-1] and df['close'][i] < df['open'][i]:  # Sweep high and bearish close
            sweeps.append(('sweep_high', df['timestamp'][i], df['high'][i]))
        elif df['low'][i] < df['low'][i-1] and df['close'][i] > df['open'][i]:  # Sweep low and bullish close
            sweeps.append(('sweep_low', df['timestamp'][i], df['low'][i]))
    return sweeps

def detect_order_blocks(df):
    """Detect simple bullish and bearish order blocks"""
    blocks = []
    for i in range(2, len(df)):
        # Bullish Order Block
        if df['close'][i-2] < df['open'][i-2] and df['close'][i-1] > df['open'][i-1]:
            blocks.append(('bullish', df['timestamp'][i-2], df['low'][i-2]))
        # Bearish Order Block
        if df['close'][i-2] > df['open'][i-2] and df['close'][i-1] < df['open'][i-1]:
            blocks.append(('bearish', df['timestamp'][i-2], df['high'][i-2]))
    return blocks

# ------------------------------------
# Fetching Data
# ------------------------------------

if st.sidebar.button("Generate Chart"):
    with st.spinner("Fetching data..."):
        try:
            binance = ccxt.kucoin()
            bars = binance.fetch_ohlcv('BTC/USDT', timeframe=selected_binance_tf, limit=num_candles)
            df = pd.DataFrame(bars, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])

            # Time to IST
            ist = pytz.timezone('Asia/Kolkata')
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms').dt.tz_localize('UTC').dt.tz_convert(ist)

            # Calculate EMA50 and EMA200
            df['EMA50'] = df['close'].ewm(span=50, adjust=False).mean()
            df['EMA200'] = df['close'].ewm(span=200, adjust=False).mean()

            # Detect supports and resistances
            supports, resistances = detect_support_resistance(df)

            # Detect liquidity sweeps
            sweeps = detect_liquidity_sweeps(df)

            # Detect order blocks
            order_blocks = detect_order_blocks(df)

            # ------------------------------------
            # Plot Chart
            # ------------------------------------

            fig = go.Figure()

            # Candlestick chart
            fig.add_trace(go.Candlestick(
                x=df['timestamp'],
                open=df['open'],
                high=df['high'],
                low=df['low'],
                close=df['close'],
                name="Candles"
            ))

            # EMA lines
            fig.add_trace(go.Scatter(
                x=df['timestamp'],
                y=df['EMA50'],
                line=dict(color='cyan', width=1),
                name="EMA 50"
            ))

            fig.add_trace(go.Scatter(
                x=df['timestamp'],
                y=df['EMA200'],
                line=dict(color='orange', width=1),
                name="EMA 200"
            ))

            # Support lines
            for time, price in supports:
                fig.add_hline(y=price, line_color='green', line_dash='dot', opacity=0.3)

            # Resistance lines
            for time, price in resistances:
                fig.add_hline(y=price, line_color='red', line_dash='dot', opacity=0.3)

            # Liquidity sweeps markers
            for sweep_type, time, price in sweeps:
                if sweep_type == 'sweep_high':
                    fig.add_trace(go.Scatter(
                        x=[time],
                        y=[price],
                        mode='markers',
                        marker=dict(color='red', size=8, symbol="triangle-up"),
                        name="Sweep High"
                    ))
                else:
                    fig.add_trace(go.Scatter(
                        x=[time],
                        y=[price],
                        mode='markers',
                        marker=dict(color='green', size=8, symbol="triangle-down"),
                        name="Sweep Low"
                    ))

            # Order block markers
            for block_type, time, price in order_blocks:
                color = 'blue' if block_type == 'bullish' else 'purple'
                fig.add_trace(go.Scatter(
                    x=[time],
                    y=[price],
                    mode='markers',
                    marker=dict(color=color, size=10, symbol="x"),
                    name=f"{block_type.capitalize()} Block"
                ))

            # Layout settings
            fig.update_layout(
                title="BTC/USDT Institutional Style Trading Chart",
                xaxis_title="Time (IST)",
                yaxis_title="Price (USDT)",
                xaxis_rangeslider_visible=False,
                template="plotly_dark",
                height=800
            )

            # Plot
            st.plotly_chart(fig, use_container_width=True)

        except Exception as e:
            st.error(f"Error fetching or plotting data: {e}")
