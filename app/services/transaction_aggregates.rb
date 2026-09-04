# Shared read-side arithmetic over a user's transactions.
#
# The dashboard, budgets and reports pages all slice the same ledger, so the
# rollups live here rather than being re-derived in each service. Including
# services are expected to expose a `user` reader.
module TransactionAggregates
  private
    def ledger
      user.transactions
    end

    def month_range(month)
      month.beginning_of_month..month.end_of_month
    end

    # Expenses are stored negative (see Transaction#apply_sign_convention), so
    # every "expense" rollup here is flipped to a positive magnitude — callers
    # want "spent $412", not "-$412".
    def income_cents(month)
      ledger.income.where(occurred_on: month_range(month)).sum(:amount_cents)
    end

    def expense_cents(month)
      -ledger.expense.where(occurred_on: month_range(month)).sum(:amount_cents)
    end

    # Net worth is every account's opening balance plus every transaction that
    # has landed on or before `date`. Transfers net to zero across their two
    # legs, so they correctly leave the total unchanged.
    def net_worth_cents_on(date)
      user.accounts.sum(:starting_balance_cents) + ledger.where(occurred_on: ..date).sum(:amount_cents)
    end

    # => { Category => cents_spent }, descending, uncategorised spend dropped.
    # Memoized per month: the dashboard reads the same month two or three times
    # over (donut, insights, budget comparison) in a single render.
    def expense_by_category(month)
      @expense_by_category ||= {}
      @expense_by_category[month.beginning_of_month] ||= begin
        totals = ledger.expense.where(occurred_on: month_range(month)).group(:category_id).sum(:amount_cents)
        categories = user.categories.where(id: totals.keys.compact).index_by(&:id)

        totals.filter_map { |category_id, cents| [ categories[category_id], -cents ] if categories[category_id] }
              .sort_by { |_category, cents| -cents }
              .to_h
      end
    end

    def money(cents)
      Money.new(cents, "USD")
    end

    # The most recent month that has finished. Every month-over-month figure on
    # the dashboard and reports compares complete months, so a partial current
    # month never shows up as a collapse in spending.
    def last_complete_month(today)
      today.prev_month.beginning_of_month
    end
end
