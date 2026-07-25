module CategoriesHelper
  def category_color_classes(color)
    case color
    when "red" then "bg-red-500"
    when "orange" then "bg-orange-500"
    when "yellow" then "bg-yellow-500"
    when "green" then "bg-green-500"
    when "teal" then "bg-teal-500"
    when "blue" then "bg-blue-500"
    when "purple" then "bg-purple-500"
    when "pink" then "bg-pink-500"
    end
  end
end
