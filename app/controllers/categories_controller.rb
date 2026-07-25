class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ edit update destroy ]

  def index
    @categories = Current.user.categories.order(:name)
  end

  def new
    @category = Current.user.categories.build
  end

  def create
    @category = Current.user.categories.build(category_params)

    if @category.save
      redirect_to categories_path, notice: "Category created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Category updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_path, notice: "Category deleted.", status: :see_other
  end

  private
    def set_category
      @category = Current.user.categories.find(params[:id])
    end

    def category_params
      params.expect(category: [ :name, :kind, :color ])
    end
end
