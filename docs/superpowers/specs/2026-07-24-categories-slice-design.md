# Categories slice — design

**Date:** 2026-07-24
**Status:** approved, ready for implementation plan

## Context

Second slice of Phase 4's data model, per the plan's suggested build order (Accounts →
**Categories** → Transactions → Budget → Goals → Education). `Account` already exists (previous
slice). This slice adds `Category` — the other half of what a future Transaction belongs to.

## Scope

In scope: a `Category` model (income/expense buckets with a color for visual grouping) with full
CRUD, scoped to `current_user`, plus an automatic starter set of 8 categories for newly created
users.

Out of scope (deferred): Transactions (and therefore `Category#transactions`, which doesn't exist
yet — adding `has_many :transactions` now would reference a nonexistent model), category groups/
hierarchy, editing the starter set's content without code changes (it's a fixed list for now, not
admin-configurable), backfilling default categories onto already-existing users.

## Data model

```ruby
# db/migrate/..._create_categories.rb
create_table :categories do |t|
  t.references :user, null: false, foreign_key: true
  t.string :name, null: false
  t.string :kind, null: false   # income, expense
  t.string :color, null: false  # red, orange, yellow, green, teal, blue, purple, pink
  t.timestamps
end
add_index :categories, "user_id, lower(name)", unique: true, name: "index_categories_on_user_id_and_lower_name"
```

- `Category belongs_to :user`; `User has_many :categories, dependent: :destroy`.
- `enum :kind` over `income`/`expense`.
- `enum :color` over a fixed 8-value palette: `red`, `orange`, `yellow`, `green`, `teal`, `blue`,
  `purple`, `pink`.
- Uniqueness on `name` is per-user and **case-insensitive**, enforced at both layers: a Rails
  `uniqueness: { scope: :user_id, case_sensitive: false }` validation for a clean error message,
  and a Postgres expression index on `lower(name)` scoped by `user_id` so a race condition can't
  create two case-variant duplicates.
- **Delete is a hard delete**, same reasoning as Account: no Transactions exist yet to be
  orphaned by deleting a category.

## Color rendering — literal Tailwind classes only, never interpolated

Tailwind's build only includes classes that appear as literal strings somewhere in scanned
source. A dynamically interpolated class name (e.g. `"bg-#{category.color}-500"` in a view) would
look correct in the ERB source but silently fail to compile into the actual CSS — Tailwind's
scanner can't see through string interpolation to know `bg-red-500` needs to exist.

The fix: a helper method with one literal `when` branch per color, each returning a complete,
literal class string:

```ruby
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
```

The implementation plan must verify this compiles for real — same as the UI-kit slice's Task 2
did for `.btn`/`.table` — by building Tailwind and grepping the output for each `bg-*-500` class,
not just trusting that the code looks right.

## Default starter categories

New users get 8 categories automatically — one per color, covering both kinds:

| Name | Kind | Color |
|---|---|---|
| Salary | income | green |
| Other Income | income | teal |
| Groceries | expense | orange |
| Rent | expense | red |
| Utilities | expense | blue |
| Transportation | expense | purple |
| Entertainment | expense | pink |
| Dining Out | expense | yellow |

Implemented as a service (`app/services/seed_default_categories.rb`, one public `#call` method,
matching CLAUDE.md's "business logic belongs in `app/services/`" convention), invoked from a
`User#after_create` callback (not `after_create_commit` — the implementation plan corrected this
during Task 2: seeding is a same-database write with no external system involved, so it should
roll back atomically with the user creation on failure, which only plain `after_create` gives you).

This only fires for users created **after** this ships. Already-existing users (the seeded
demo/alex accounts, the production `SEED_ADMIN_*` login) will not retroactively get default
categories — this is normal `after_create` behavior, not something this slice works around.

## Validations

- `name`: presence, uniqueness scoped to `user_id`, case-insensitive
- `kind`: presence (the `enum` mechanism itself rejects invalid values)
- `color`: presence (same)

## Controller, routes, views

- `resources :categories, except: :show` — applying the lesson from the Accounts slice's final
  review up front this time (a bare `resources` would generate an unbuilt `show` route that 500s
  instead of 404ing).
- `CategoriesController`: `index`, `new`, `create`, `edit`, `update`, `destroy`. Every action
  scoped through `Current.user.categories`, never bare `Category.find` — same pattern as
  `AccountsController`.
- Views: DaisyUI table for `index` (name, kind, a small colored dot using
  `category_color_classes`, edit/delete actions), shared `_form` partial. Color picker is a plain
  `form.select` for v1 — not a custom swatch-click widget. YAGNI; upgradeable later without a
  data model change since `color` is already a clean enum.

## Testing

- Model test: presence validations, case-insensitive uniqueness (including the actual collision
  case — same name, different case, same user — correctly rejected), enum values for both `kind`
  and `color`, the `user` association.
- Service test (`SeedDefaultCategoriesTest`): calling `SeedDefaultCategories.new(user).call`
  creates exactly the 8 expected categories with the correct name/kind/color for each.
- One integration test on `User` confirming `User.create!` actually triggers the callback end to
  end (not re-testing the service's own detail, just the seam between them).
- Controller/integration test: full CRUD as a signed-in user, cross-user 404 on `edit`/`update`/
  `destroy` — same shape as `AccountsControllerTest`.
- No system test — manual browser check instead (boot `bin/dev` or the real-HTTP-walkthrough
  substitute used throughout this session, exercise create/edit/delete, and specifically confirm
  the color dot actually renders with real color, not a missing/broken class).
