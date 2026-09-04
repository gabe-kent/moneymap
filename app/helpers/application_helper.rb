module ApplicationHelper
  # Text colour for a figure that carries a judgement: green when the number is
  # moving the right way, red when net worth is going backwards, a subdued grey
  # when it is merely worth noticing.
  TONE_CLASSES = {
    good: "text-invoca-green",
    bad: "text-problem-red",
    caution: "text-gray-700",
    neutral: "text-gray-500"
  }.freeze

  def tone_class(tone)
    TONE_CLASSES.fetch(tone, TONE_CLASSES[:neutral])
  end

  def trend_icon(direction, **options)
    icon direction == :down ? "arrow-down-right" : "arrow-up-right", **options
  end

  # Always two decimals, always the symbol, minus outside the symbol
  # ("-$1,046.77") — dashboards read badly when some figures show cents and
  # others don't, and "$-1,046.77" reads as a typo.
  def money_amount(money)
    money.format(sign_before_symbol: true)
  end

  # Explicitly signed, for a ledger row: income reads "+$1,800.00", spend "-$68.40".
  def signed_money_amount(money)
    "#{money.negative? ? '-' : '+'}#{money.abs.format}"
  end

  def transaction_amount_class(transaction)
    case transaction.txn_type
    when "income" then "text-invoca-green"
    when "transfer" then "text-gray-600"
    else "text-green-black"
    end
  end

  def account_balance_class(balance)
    balance.negative? ? "text-problem-red" : "text-green-black"
  end

  # Card shell used by every panel on the dashboard, budgets and reports pages.
  def panel_classes(extra = nil)
    class_names("bg-white border border-gray-200 rounded-2xl shadow-xs", extra)
  end

  def section_heading_classes
    "text-base font-bold text-green-black"
  end

  def eyebrow_classes
    "text-[11px] font-semibold tracking-[0.08em] uppercase text-gray-500"
  end

  def primary_button_classes
    "inline-flex items-center gap-2 bg-invoca-green text-white py-[11px] px-[18px] rounded-xl " \
      "font-semibold text-sm cursor-pointer transition-colors hover:bg-green-600"
  end

  def ghost_button_classes
    "inline-flex items-center gap-2 bg-white border border-gray-200 text-green-black py-[11px] px-[18px] " \
      "rounded-xl font-semibold text-sm cursor-pointer transition-colors hover:bg-gray-50"
  end

  def time_of_day_greeting(now = Time.current)
    case now.hour
    when 0...12 then "Good morning"
    when 12...18 then "Good afternoon"
    else "Good evening"
    end
  end
end
