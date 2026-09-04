# The budgets page for one month: a headline roll-up plus one card per budgeted
# category, each showing real spend against its target.
#
# Categories that have a budget but no spend still appear (at 0%); spend in a
# category with no budget is counted in `unbudgeted` rather than silently
# dropped, so the headline "spent of budgeted" figure stays honest.
class BudgetOverview
  include TransactionAggregates

  WATCH_THRESHOLD = 85 # percent of target at which a card flips to "Watch"

  Line = Data.define(:budget, :category, :spent, :target, :percent, :bar_width, :status, :remaining_text)
  Summary = Data.define(:spent, :target, :remaining, :percent, :bar_width)
  Result = Data.define(:month, :summary, :lines, :unbudgeted, :budgeted_category_ids)

  def initialize(user, month: Date.current.beginning_of_month)
    @user = user
    @month = month.beginning_of_month
  end

  def call
    lines = budgets.map { |budget| line_for(budget) }

    Result.new(
      month: month,
      summary: summary(lines),
      lines: lines,
      unbudgeted: money(spending.reject { |category, _| budgeted_category_ids.include?(category.id) }.values.sum),
      budgeted_category_ids: budgeted_category_ids
    )
  end

  private
    attr_reader :user, :month

    def budgets
      @budgets ||= user.budgets.for_month(month).includes(:category).sort_by { |budget| -budget.target_cents }
    end

    def budgeted_category_ids
      @budgeted_category_ids ||= budgets.map(&:category_id)
    end

    def spending
      @spending ||= expense_by_category(month)
    end

    def spent_by_category_id
      @spent_by_category_id ||= spending.transform_keys(&:id)
    end

    def spent_cents(category_id)
      spent_by_category_id.fetch(category_id, 0)
    end

    def line_for(budget)
      spent = spent_cents(budget.category_id)
      percent = (spent.to_f / budget.target_cents * 100).round

      Line.new(
        budget: budget,
        category: budget.category,
        spent: money(spent),
        target: budget.target,
        percent: percent,
        bar_width: [ percent, 100 ].min,
        status: status_for(percent),
        remaining_text: percent > 100 ? "#{money(spent - budget.target_cents).format} over" : "#{money(budget.target_cents - spent).format} left"
      )
    end

    def status_for(percent)
      if percent > 100 then :over
      elsif percent >= WATCH_THRESHOLD then :watch
      else :on_track
      end
    end

    def summary(lines)
      target = lines.sum { |line| line.target.cents }
      spent = lines.sum { |line| line.spent.cents }
      percent = target.zero? ? 0 : (spent.to_f / target * 100).round

      Summary.new(
        spent: money(spent),
        target: money(target),
        remaining: money([ target - spent, 0 ].max),
        percent: percent,
        bar_width: [ percent, 100 ].min
      )
    end
end
