const Map<String, String> metricExplanations = {
  'pe_ratio':
      'Price-to-Earnings ratio tells you how many years of current earnings you\'re paying for when you buy the stock. A P/E of 20 means you\'re paying 20x annual earnings. Lower P/E often means cheaper, but very low P/E can also signal problems. Compare with sector peers for context.',
  'roe':
      'Return on Equity measures how much profit the company generates for every rupee of shareholder money invested. An ROE above 15% is generally good. Consistently high ROE indicates excellent management and a strong competitive advantage.',
  'roce':
      'Return on Capital Employed measures how efficiently the company uses all its capital (equity + debt) to generate profits. ROCE above 15% is good, above 20% is excellent. It\'s more comprehensive than ROE because it considers debt too.',
  'debt_to_equity':
      'Compares the company\'s total debt to shareholder equity. A ratio below 1 means the company has more equity than debt (conservative). Above 2 is considered highly leveraged. Zero means the company is debt-free.',
  'beta':
      'Measures how much the stock moves relative to the market. Beta of 1 means it moves in line with Nifty. Above 1 means more volatile (a beta of 1.5 means if Nifty falls 10%, this stock may fall 15%). Below 1 means less volatile.',
  'sharpe':
      'Measures return per unit of total risk taken. A Sharpe ratio above 1 is good, above 2 is excellent. It helps you compare investments that have different risk levels \u2014 higher Sharpe means you\'re getting better returns for the risk you\'re taking.',
  'sortino':
      'Similar to Sharpe ratio but only considers downside risk (losses), not total volatility. This is more useful because upside volatility is good for investors. A higher Sortino ratio means better returns relative to the risk of losing money.',
  'max_drawdown':
      'The largest peak-to-trough decline in the investment\'s value. A max drawdown of -30% means at the worst point, your investment was down 30% from its peak. Smaller drawdowns (closer to 0%) indicate more stable investments.',
  'xirr':
      'Extended Internal Rate of Return calculates your actual annualized return accounting for when each investment was made. Unlike CAGR, XIRR handles irregular cash flows (SIPs, additional purchases, partial withdrawals) accurately.',
  'cagr':
      'Compound Annual Growth Rate shows the annualized return assuming a single lump-sum investment. CAGR of 15% means your money grew at 15% per year on average. It smooths out year-to-year volatility to give you the big picture.',
  'alpha':
      'The extra return above what the benchmark (like Nifty) delivered. Alpha of 3% means the fund/stock outperformed its benchmark by 3% annually. Positive alpha indicates skilled management or superior stock selection.',
  'expense_ratio':
      'The annual fee charged by a mutual fund, deducted from your returns. An expense ratio of 1.5% means for every \u20B91 lakh invested, \u20B91,500 goes to fund fees annually. Lower is always better \u2014 even small fee differences compound significantly over decades.',
  'aum':
      'Assets Under Management \u2014 the total money managed by the fund. Larger AUM (above \u20B9500 Cr) generally means better liquidity, lower impact costs, and more stability. Very small AUM funds may face challenges with redemption pressure.',
  'peg_ratio':
      'Price/Earnings-to-Growth ratio adjusts the P/E for the company\'s growth rate. PEG below 1 suggests the stock may be undervalued for its growth. PEG of 1 means fairly valued. Above 2 means you\'re paying a premium relative to growth.',
  'free_cash_flow':
      'Cash left over after the company pays for operations and investments. Positive FCF means the business generates real cash that can be used for dividends, buybacks, or debt repayment. Negative FCF may indicate heavy investment or financial stress.',
  'market_cap':
      'Total market value of all the company\'s shares (share price \u00d7 total shares). Large cap (\u20B920,000+ Cr) are stable blue chips, mid cap (\u20B95,000-20,000 Cr) offer growth with moderate risk, small cap (below \u20B95,000 Cr) are higher risk but higher potential.',
  'p_b':
      'Price-to-Book ratio compares the stock price to the company\'s book value (assets minus liabilities per share). P/B below 1 means the stock trades below its asset value, which could indicate undervaluation or fundamental problems.',
  'forward_pe':
      'P/E ratio based on expected future earnings (analyst estimates) rather than past earnings. A lower forward P/E compared to trailing P/E suggests analysts expect earnings to grow. Useful for fast-growing companies where past earnings don\'t reflect future potential.',
  'dividend_yield':
      'Annual dividend payment as a percentage of the current stock price. A yield of 3% means for every \u20B91 lakh invested, you receive \u20B93,000 in dividends annually. Higher yields provide regular income, but very high yields may signal the company is struggling to grow.',
  'std_dev':
      'Standard deviation measures how much returns vary from the average. Lower std dev means more predictable returns. A fund with 12% average return and 5% std dev is more consistent than one with 15% return and 20% std dev.',
  'rolling_return_consistency':
      'Measures how consistently the fund delivers positive returns across different rolling time periods. A lower number (closer to 0%) indicates very consistent performance regardless of when you invested. Higher values indicate unpredictable returns.',
  'gross_margin':
      'Revenue minus cost of goods sold, as a percentage of revenue. A gross margin of 40% means for every \u20B9100 of revenue, \u20B940 is left after direct production costs. Higher gross margins indicate better pricing power or lower production costs.',
  'operating_margin':
      'Profit from core business operations as a percentage of revenue, after deducting operating expenses but before interest and taxes. Higher operating margins (above 15%) indicate efficient operations and good cost control.',
  'profit_margin':
      'Net profit as a percentage of total revenue after ALL expenses (operations, interest, taxes). A profit margin of 10% means the company keeps \u20B910 as profit from every \u20B9100 of revenue. Higher margins mean more profitable and efficient operations.',
  'total_debt':
      'The total amount of money the company has borrowed (short-term + long-term). Compare with equity (debt-to-equity ratio) and cash reserves to assess if the debt level is manageable. Companies with high debt face more risk during economic downturns.',
  'payout_ratio':
      'The percentage of earnings the company pays out as dividends. A payout ratio of 40% means the company distributes 40% of profits and retains 60% for growth. Very high ratios (above 80%) may be unsustainable and leave little room for reinvestment.',
  'price_to_book':
      'Price-to-Book ratio compares the stock price to the company\'s net asset value per share. A P/B below 1 could mean the stock is trading at a discount to its assets. Useful especially for banks, NBFCs, and asset-heavy companies.',
  'interest_coverage':
      'How many times the company\'s operating profit can cover its interest payments. A ratio of 5x means profits are 5 times the interest expense. Below 1.5x is risky as the company may struggle to service its debt. Higher is safer.',
  'revenue_growth':
      'Year-over-year percentage change in total revenue (sales). Positive revenue growth means the company is expanding its business, gaining market share, or raising prices. Sustained double-digit growth (15%+) indicates a fast-growing business.',
  'earnings_growth':
      'Year-over-year percentage change in earnings (profits). Growing earnings faster than revenue indicates improving efficiency and margins. Negative earnings growth is a warning sign unless the company is investing heavily for future growth.',
  'eps':
      'Earnings Per Share \u2014 net profit divided by total number of shares. EPS of \u20B950 means the company earns \u20B950 per share annually. Growing EPS over time is one of the strongest indicators of a good investment. Negative EPS means the company is losing money.',
  'promoter_holding':
      'Percentage of shares held by the company\'s founders/promoters. High promoter holding (above 50%) signals strong insider confidence \u2014 the people who know the business best have significant skin in the game. Declining promoter holding can be a red flag.',
  'fii_holding':
      'Percentage of shares held by Foreign Institutional Investors (global mutual funds, hedge funds, pension funds). High FII holding (above 20%) indicates the stock meets global investment standards. However, FII selling during global crises can increase volatility.',
  'dii_holding':
      'Percentage held by Domestic Institutional Investors (Indian mutual funds, insurance companies like LIC, pension funds). Strong DII holding provides buying support during market corrections, as these institutions invest with a long-term view.',
  'rsi_14':
      '14-day Relative Strength Index measures recent price momentum on a 0-100 scale. RSI above 70 means "overbought" (may be due for a pullback), below 30 means "oversold" (may be due for a bounce). Between 40-60 is neutral territory.',
  'category_rank':
      'The fund\'s rank within its SEBI sub-category based on our overall score. A rank of 5 means it\'s the 5th best fund in its category. Lower rank is better. Compare funds within the same category for a fair comparison.',
  'nav':
      'Net Asset Value is the per-unit market value of all securities held by the fund, minus expenses. NAV of \u20B9100 means each unit of the fund is worth \u20B9100. A higher NAV doesn\'t mean the fund is expensive \u2014 what matters is the NAV growth rate (returns).',
  'returns_1y':
      'The annualized return over the last 1 year. Short-term returns can be heavily influenced by market conditions, so don\'t rely on 1-year returns alone. Compare with the fund\'s benchmark and category average for context.',
  'returns_3y':
      'The compound annual growth rate (CAGR) over the last 3 years. This is a more reliable indicator than 1-year returns as it smooths out short-term market fluctuations. 3-year returns above 12% CAGR are generally strong for equity funds.',
  'returns_5y':
      'The compound annual growth rate (CAGR) over the last 5 years. This covers at least one full market cycle and is the most reliable indicator of a fund\'s ability to generate consistent returns through various market conditions.',
  'risk_level':
      'SEBI-mandated risk classification ranging from Low to Very High. It\'s based on the fund\'s investment strategy and historical volatility. Match the risk level with your investment horizon \u2014 high-risk funds need a 5+ year holding period to smooth out volatility.',
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
