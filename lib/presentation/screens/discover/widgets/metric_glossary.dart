const Map<String, String> metricExplanations = {
  'pe_ratio':
      'How many years of current earnings you\'re paying for. Lower often means cheaper.',
  'roe':
      'How well the company turns shareholder money into profits. Higher is better.',
  'roce':
      'How efficiently the company uses all capital. Above 15% is generally good.',
  'debt_to_equity': 'How much debt vs equity. Below 1 is conservative.',
  'beta': 'Market sensitivity. 1 = moves with market, >1 = more volatile.',
  'sharpe': 'Return per unit of risk. Above 1 is good, above 2 is excellent.',
  'sortino':
      'Like Sharpe but only penalizes downside risk. Higher is better.',
  'max_drawdown':
      'Worst drop from peak to trough. Smaller (closer to 0) is better.',
  'xirr':
      'Your actual annualized return accounting for when you invested.',
  'cagr': 'Compound annual growth rate assuming a lump-sum investment.',
  'alpha': 'Extra return above what the benchmark delivered.',
  'expense_ratio':
      'Annual fee charged by the fund. Lower means more of your returns stay with you.',
  'aum': 'Total money managed by the fund. Larger usually means more liquid.',
  'peg_ratio':
      'P/E adjusted for growth. Below 1 may indicate undervaluation.',
  'free_cash_flow':
      'Cash left after operations and investments. Positive is healthy.',
  'market_cap': 'Total market value of the company\'s shares.',
  'p_b': 'Price relative to book value. Lower may indicate undervaluation.',
  'forward_pe': 'P/E based on expected future earnings, not past.',
  'dividend_yield': 'Annual dividend as percentage of stock price.',
  'std_dev': 'How much returns vary. Lower means more predictable.',
  'rolling_return_consistency':
      'How consistently the fund delivers positive returns over rolling periods.',
  'gross_margin':
      'Revenue minus cost of goods, as a percentage. Higher means better pricing power.',
  'operating_margin':
      'Profit from core operations as a percentage of revenue. Higher is better.',
  'profit_margin':
      'Net profit as a percentage of revenue after all expenses. Higher is better.',
  'fcf_yield':
      'Free cash flow relative to market cap. Higher means more cash generation per rupee invested.',
  'total_debt':
      'Total borrowings of the company. Compare with equity and cash to assess leverage.',
  'payout_ratio':
      'Percentage of earnings paid as dividends. Very high (>80%) may be unsustainable.',
  'price_to_book':
      'Price relative to book value. Lower may indicate undervaluation.',
  'interest_coverage':
      'How many times operating profit covers interest payments. Below 1.5 is risky.',
  'revenue_growth':
      'Year-over-year change in total revenue. Positive means the company is growing its top line.',
  'earnings_growth':
      'Year-over-year change in earnings per share. Positive means improving profitability.',
  'eps':
      'Earnings per share — net profit divided by total shares. Higher is better.',
  'promoter_holding':
      'Percentage of shares held by company promoters. Higher often signals insider confidence.',
  'fii_holding':
      'Percentage held by Foreign Institutional Investors. Rising FII interest is a bullish signal.',
  'dii_holding':
      'Percentage held by Domestic Institutional Investors like mutual funds and insurance companies.',
  'rsi_14':
      '14-day Relative Strength Index. Above 70 is overbought, below 30 is oversold.',
  'category_rank':
      'Fund rank within its sub-category by overall score. Lower is better.',
  'nav':
      'Net Asset Value — the per-unit market value of all securities held by the fund.',
  'returns_1y': 'Annualized return over the last 1 year.',
  'returns_3y': 'Annualized return over the last 3 years (CAGR).',
  'returns_5y': 'Annualized return over the last 5 years (CAGR).',
  'risk_level':
      'Fund risk classification assigned by SEBI. Ranges from Low to Very High.',
  'score_financial_health':
      'Measures the company\'s financial strength using Return on Equity (ROE), Return on Capital Employed (ROCE), debt levels, and cash flow quality. A high score means the company efficiently generates profits, manages debt well, and produces real cash from operations.',
  'score_valuation':
      'Evaluates whether the stock is fairly priced using P/E ratio, PEG ratio, price-to-book, and comparison with sector peers. A high score suggests the stock may be undervalued relative to its earnings and growth, offering better value for money.',
  'score_growth':
      'Assesses the company\'s growth trajectory using revenue growth, earnings growth, 5-year CAGR, and margin trends. A high score indicates the business is expanding rapidly with improving profitability over time.',
  'score_momentum':
      'Tracks recent price performance using RSI, MACD, moving average trends, and breakout signals. A high score means the stock has strong upward price momentum \u2014 though momentum alone doesn\'t guarantee future returns.',
  'score_smart_money':
      'Analyzes institutional ownership patterns \u2014 FII, DII, and promoter holdings plus quarter-over-quarter changes. A high score means smart money (professional fund managers and insiders) is actively buying, signaling confidence in the company.',
  'score_risk_shield':
      'Measures downside protection using beta, pledged shares, debt levels, and earnings stability. A high score means the stock has lower volatility, minimal pledge risk, and stable earnings \u2014 offering better protection during market downturns.',
};
