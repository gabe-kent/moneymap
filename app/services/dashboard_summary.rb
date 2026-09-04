# Everything the dashboard renders, computed in one pass.
#
# Month-over-month figures (KPI deltas, insights, the category donut) compare
# *complete* months, so `analysis_month` is the last month that has finished.
# The cash-flow chart is the exception: it deliberately runs through today so
# the current month is visible, and labels that bar "MTD".
class DashboardSummary
  include TransactionAggregates

  BAR_SCALE = 160 # px, the tallest a cash-flow bar can draw

  Kpi = Data.define(:label, :value, :delta_text, :direction, :tone)
  Bar = Data.define(:label, :income, :expense, :income_height, :expense_height)
  Insight = Data.define(:icon, :text, :tone)
  AccountCard = Data.define(:account, :balance)
  Slice = Data.define(:name, :hex, :amount, :percent)

  Result = Data.define(
    :analysis_month, :kpis, :cash_flow, :insights, :accounts,
    :donut_slices, :donut_total, :donut_gradient, :recent_transactions
  )

  def initialize(user, today: Date.current)
    @user = user
    @today = today
    @analysis_month = last_complete_month(today)
    @previous_month = @analysis_month.prev_month
  end

  def call
    Result.new(
      analysis_month: analysis_month,
      kpis: kpis,
      cash_flow: cash_flow,
      insights: insights,
      accounts: account_cards,
      donut_slices: donut_slices,
      donut_total: money(analysis_spending.values.sum),
      donut_gradient: donut_gradient,
      recent_transactions: recent_transactions
    )
  end

  private
    attr_reader :user, :today, :analysis_month, :previous_month

    def kpis
      [
        net_worth_kpi,
        change_kpi("Income · #{month_name(analysis_month)}", income_cents(analysis_month), income_cents(previous_month), good_when: :up),
        change_kpi("Expenses · #{month_name(analysis_month)}", expense_cents(analysis_month), expense_cents(previous_month), good_when: :down)
      ]
    end

    def net_worth_kpi
      now = net_worth_cents_on(today)
      delta = now - net_worth_cents_on(today.prev_month.end_of_month)

      Kpi.new(
        label: "Net worth",
        value: money(now).format,
        delta_text: "#{delta.negative? ? '-' : '+'}#{money(delta.abs).format} this month",
        direction: delta.negative? ? :down : :up,
        tone: delta.negative? ? :bad : :good
      )
    end

    def change_kpi(label, current, baseline, good_when:)
      up = current >= baseline
      # Spending more than last month is worth noticing, not alarming — an
      # unfavourable move reads as :caution, and :bad is reserved for net worth
      # actually going backwards.
      tone = if baseline.zero? then :neutral
      elsif up == (good_when == :up) then :good
      else :caution
      end

      Kpi.new(
        label: label,
        value: money(current).format,
        delta_text: baseline.zero? ? "no #{month_name(previous_month)} baseline" : "#{up ? '+' : '-'}#{percent_change(current, baseline)}% vs #{month_name(previous_month)}",
        direction: up ? :up : :down,
        tone: tone
      )
    end

    def percent_change(current, baseline)
      (((current - baseline).to_f / baseline).abs * 100).round
    end

    # Two months of history plus the month in progress.
    def cash_flow
      months = [ previous_month, analysis_month, today.beginning_of_month ]
      totals = months.map { |month| [ income_cents(month), expense_cents(month) ] }
      ceiling = [ totals.flatten.max, 1 ].max

      months.zip(totals).map do |month, (income, expense)|
        label = month == today.beginning_of_month ? "#{month_name(month)} (MTD)" : month_name(month)

        Bar.new(
          label: label,
          income: money(income),
          expense: money(expense),
          income_height: (income.to_f / ceiling * BAR_SCALE).round,
          expense_height: (expense.to_f / ceiling * BAR_SCALE).round
        )
      end
    end

    # Three cards, taken in priority order from whichever candidates apply.
    def insights
      [ biggest_mover_insight, savings_rate_insight, credit_balance_insight, net_worth_insight ].compact.first(3)
    end

    def biggest_mover_insight
      previous = expense_by_category(previous_month).transform_keys(&:id)
      mover, current_cents = expense_by_category(analysis_month)
        .max_by { |category, cents| cents - previous.fetch(category.id, 0) }
      return if mover.nil?

      baseline = previous.fetch(mover.id, 0)
      return if baseline.zero? || current_cents <= baseline

      Insight.new(
        icon: "trending-up",
        tone: :neutral,
        text: "#{mover.name} is up #{percent_change(current_cents, baseline)}% vs #{month_name(previous_month)} — " \
              "#{money(current_cents).format} in #{month_name(analysis_month)} vs #{money(baseline).format} the month before."
      )
    end

    def savings_rate_insight
      income = income_cents(analysis_month)
      saved = income - expense_cents(analysis_month)
      return if income.zero?

      if saved.positive?
        Insight.new(
          icon: "piggy-bank",
          tone: :good,
          text: "You saved #{money(saved).format} in #{month_name(analysis_month)} — #{(saved.to_f / income * 100).round}% of income."
        )
      else
        Insight.new(
          icon: "trending-up",
          tone: :bad,
          text: "You spent #{money(saved.abs).format} more than you earned in #{month_name(analysis_month)}."
        )
      end
    end

    def credit_balance_insight
      owing = account_cards.select { |card| card.account.credit? && card.balance.negative? }
                           .min_by { |card| card.balance }
      return if owing.nil?

      Insight.new(
        icon: "credit-card",
        tone: :neutral,
        text: "#{owing.account.name} carries a #{owing.balance.abs.format} balance — pay it down to avoid interest."
      )
    end

    def net_worth_insight
      Insight.new(
        icon: "wallet",
        tone: :neutral,
        text: "Your net worth is #{money(net_worth_cents_on(today)).format} across #{user.accounts.count} accounts."
      )
    end

    def account_cards
      @account_cards ||= user.accounts.order(:name).map do |account|
        AccountCard.new(account: account, balance: account.current_balance)
      end
    end

    def analysis_spending
      @analysis_spending ||= expense_by_category(analysis_month)
    end

    def donut_slices
      total = analysis_spending.values.sum
      return [] if total.zero?

      analysis_spending.map do |category, cents|
        Slice.new(
          name: category.name,
          hex: category.hex_color,
          amount: money(cents),
          percent: (cents.to_f / total * 100).round(1)
        )
      end
    end

    # A conic-gradient built from the running total of each slice, so the ring
    # is one painted element rather than a stack of SVG arcs.
    def donut_gradient
      cursor = 0.0
      stops = donut_slices.map do |slice|
        start, finish = cursor, cursor + slice.percent
        cursor = finish
        "#{slice.hex} #{start.round(2)}% #{finish.round(2)}%"
      end

      stops.any? ? "conic-gradient(#{stops.join(', ')})" : "conic-gradient(#DDE1DF 0% 100%)"
    end

    def recent_transactions
      ledger.includes(:account, :category).order(occurred_on: :desc, created_at: :desc).limit(5)
    end

    def month_name(month)
      month.strftime("%B")
    end
end
