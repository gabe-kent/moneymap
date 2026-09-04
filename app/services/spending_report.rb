# The reports page: a net-worth trend line, income-vs-expense bars, a category
# breakdown for the last complete month, and the descriptions money actually
# went to.
class SpendingReport
  include TransactionAggregates

  MONTHS = 3          # points on the trend line / bars in the chart
  BAR_SCALE = 160     # px, tallest income-vs-expense bar
  CHART = { left: 60, right: 540, top: 25, bottom: 170 }.freeze # SVG viewBox 0 0 600 200

  Point = Data.define(:label, :value, :x, :y)
  Bar = Data.define(:label, :income, :expense, :income_height, :expense_height)
  BreakdownRow = Data.define(:name, :hex, :amount, :bar_width)
  SourceRow = Data.define(:description, :category, :count, :total)

  Result = Data.define(
    :analysis_month, :range_label, :net_worth, :net_worth_points, :line_points,
    :area_points, :cash_flow, :breakdown, :top_sources
  )

  def initialize(user, today: Date.current)
    @user = user
    @today = today
    @analysis_month = last_complete_month(today)
  end

  def call
    points = net_worth_points

    Result.new(
      analysis_month: analysis_month,
      range_label: range_label,
      net_worth: money(net_worth_cents_on(today)),
      net_worth_points: points,
      line_points: points.map { |point| "#{point.x},#{point.y}" }.join(" "),
      area_points: area_points(points),
      cash_flow: cash_flow,
      breakdown: breakdown,
      top_sources: top_sources
    )
  end

  private
    attr_reader :user, :today, :analysis_month

    def months
      @months ||= (MONTHS - 1).downto(0).map { |ago| (today << ago).beginning_of_month }
    end

    def range_label
      "#{months.first.strftime('%B')} – #{months.last.strftime('%B %Y')}"
    end

    def month_label(month)
      month == today.beginning_of_month ? "#{month.strftime('%b')} (MTD)" : month.strftime("%b")
    end

    # Net worth as at the end of each month in range — except the month in
    # progress, which is measured as at today.
    def net_worth_points
      values = months.map { |month| net_worth_cents_on([ month.end_of_month, today ].min) }
      low, high = values.minmax
      span = (high - low).nonzero? || 1
      step = months.size > 1 ? (CHART[:right] - CHART[:left]).to_f / (months.size - 1) : 0

      months.each_with_index.map do |month, index|
        Point.new(
          label: month_label(month),
          value: money(values[index]),
          x: (CHART[:left] + step * index).round(1),
          y: (CHART[:bottom] - (values[index] - low).to_f / span * (CHART[:bottom] - CHART[:top])).round(1)
        )
      end
    end

    # Close the trend line down to the baseline so it can be filled as a band.
    def area_points(points)
      "#{points.map { |point| "#{point.x},#{point.y}" }.join(' ')} #{CHART[:right]},190 #{CHART[:left]},190"
    end

    def cash_flow
      totals = months.map { |month| [ income_cents(month), expense_cents(month) ] }
      ceiling = [ totals.flatten.max, 1 ].max

      months.zip(totals).map do |month, (income, expense)|
        Bar.new(
          label: month_label(month),
          income: money(income),
          expense: money(expense),
          income_height: (income.to_f / ceiling * BAR_SCALE).round,
          expense_height: (expense.to_f / ceiling * BAR_SCALE).round
        )
      end
    end

    def breakdown
      spending = expense_by_category(analysis_month)
      ceiling = [ spending.values.max.to_i, 1 ].max

      spending.map do |category, cents|
        BreakdownRow.new(
          name: category.name,
          hex: category.hex_color,
          amount: money(cents),
          bar_width: (cents.to_f / ceiling * 100).round
        )
      end
    end

    # Grouped by description — the closest thing this schema has to a merchant.
    def top_sources
      rows = ledger.expense.where(occurred_on: months.first.beginning_of_month..today)
                   .where.not(description: [ nil, "" ])
                   .group(:description, :category_id)
                   .pluck(Arel.sql("description, category_id, COUNT(*), SUM(amount_cents)"))

      categories = user.categories.index_by(&:id)

      rows.map { |description, category_id, count, cents|
        SourceRow.new(description: description, category: categories[category_id], count: count, total: money(-cents))
      }.sort_by { |row| -row.total.cents }.first(5)
    end
end
