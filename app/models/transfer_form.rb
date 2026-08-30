class TransferForm
  include ActiveModel::Model

  attr_accessor :id, :from_account_id, :to_account_id, :amount, :occurred_on, :description

  validates :from_account_id, presence: true
  validates :to_account_id, presence: true
  validates :amount, presence: true
  validates :occurred_on, presence: true
  validate :accounts_are_different
  validate :amount_is_positive

  def self.find(user, transfer_id)
    legs = user.transactions.where(transfer_id: transfer_id).order(:amount_cents)
    raise ActiveRecord::RecordNotFound, "Couldn't find Transfer" unless legs.size == 2

    outgoing, incoming = legs.first, legs.second
    new(
      id: transfer_id,
      from_account_id: outgoing.account_id,
      to_account_id: incoming.account_id,
      amount: incoming.amount.to_s,
      occurred_on: incoming.occurred_on,
      description: incoming.description
    )
  end

  def persisted?
    id.present?
  end

  def save(user)
    return false unless valid?

    begin
      ActiveRecord::Base.transaction do
        user.transactions.where(transfer_id: id).destroy_all if persisted?

        new_id = id || SecureRandom.uuid
        cents = Monetize.parse(amount, "USD").cents

        user.transactions.create!(account_id: from_account_id, amount_cents: -cents, txn_type: "transfer", transfer_id: new_id, occurred_on: occurred_on, description: description)
        user.transactions.create!(account_id: to_account_id, amount_cents: cents, txn_type: "transfer", transfer_id: new_id, occurred_on: occurred_on, description: description)

        self.id = new_id
      end
    rescue ActiveRecord::RecordInvalid => e
      errors.add(:base, e.record.errors.full_messages.to_sentence)
      return false
    end

    true
  end

  def destroy(user)
    user.transactions.where(transfer_id: id).destroy_all
  end

  private
    def accounts_are_different
      return if from_account_id.blank? || to_account_id.blank?
      errors.add(:to_account_id, "must be different from the from account") if from_account_id == to_account_id
    end

    def amount_is_positive
      return if amount.blank?
      errors.add(:amount, "must be greater than zero") if Monetize.parse(amount, "USD").cents <= 0
    end
end
