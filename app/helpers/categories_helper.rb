module CategoriesHelper
  # A category name with its colour dot, as a pill. Used in the transactions
  # table and the reports tables.
  def category_chip(category)
    return transfer_chip if category.nil?

    tag.span class: "inline-flex items-center gap-1.5 py-1 px-2.5 rounded-full text-xs font-semibold text-green-black",
             style: "background-color: #{category.hex_color}22" do
      concat tag.span("", class: "size-1.5 rounded-full shrink-0", style: "background-color: #{category.hex_color}")
      concat category.name
    end
  end

  def transfer_chip
    tag.span class: "inline-flex items-center gap-1.5 py-1 px-2.5 rounded-full bg-gray-100 text-xs font-semibold text-gray-700" do
      concat icon("arrow-left-right", class: "size-3")
      concat "Transfer"
    end
  end

  def category_dot(category, size: "size-2.5")
    tag.span "", class: class_names("rounded-full shrink-0 inline-block", size),
                 style: "background-color: #{category&.hex_color || '#A9B2B0'}"
  end
end
