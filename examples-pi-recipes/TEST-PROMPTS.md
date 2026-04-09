# Test prompts for 'pi-recipe' development

Launch with: `just analyst`

## btc price plotting

Fetch bitcoin price data from an API and chart the results inline.

**most explicit**

```txt
Fetch 30 days of Bitcoin price history from CoinGecko:
https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=30

The response has a "prices" array where each entry is [unix_ms, price_usd].
Save the raw JSON to data/, write a Python script in scripts/ that parses it
and plots a line chart (dates on x-axis, USD on y-axis, dark style), save the
chart to charts/btc-30d.png, then explain what the chart shows.
```

**giving guidance**
```txt
Use bash to fetch 14 days of Bitcoin price history from CoinGecko. The endpoint is: 
https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=14 — the 
response JSON has a "prices" array where each entry is [unix_ms, price]. Extract that 
with jq. Then use the chart tool to plot it as a line chart — convert the unix timestamps 
to dates for the x-axis, price in USD on the y-axis, title "BTC/USD — Last 30 Days", and 
use a dark style.
```

**typical, naive user**
```txt
Use https://api.coingecko.com/api/v3/coins/bitcoin/market_chart?vs_currency=usd&days=14 and chart the bitcoin price
```

---

## math tutor

```txt
Please provide an example math problem - linear algebra - then solve it showing all steps.  Use charts to explain the problem and show your solution.
 ```