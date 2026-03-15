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
};
