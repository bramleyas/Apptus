class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  has_many :statuses, dependent: :destroy
  has_many :messages, dependent: :destroy

  has_many :chat_members, dependent: :destroy
  has_many :chats, through: :chat_members

  has_many :owned_chats, foreign_key: 'owner_id', class_name: 'Chat'

  has_many :incoming_contacts, foreign_key: 'target_id',  class_name: 'Contact', dependent: :destroy
  has_many :outgoing_contacts, foreign_key: 'creator_id', class_name: 'Contact', dependent: :destroy

  enum role: %i[basic admin system]

  validates :role, inclusion: { in: roles.keys }
  validates :name, presence: true, length: { in: 2..255 }
  validates :colour, allow_blank: true, format: /#[A-F0-9]{6}/
  validates :contact_number, allow_blank: true, length: { in: 12..12 }

  before_create do
    self.colour = COLOURS.sample
    self.contact_number =
      Array.new(12) { ('0'..'9').to_a.sample }.join while contact_number.nil? || User.exists?(contact_number:)
  end

  def title_name = name.titlecase
  def first_name = name.split.first.titlecase
  def initials   = name.split.first(2).map(&:chr).join.upcase
  def nice_contact_number = contact_number.chars.each_slice(4).map(&:join).join('-')

  def incoming_contact_requests
    User.joins(:outgoing_contacts).where(outgoing_contacts: { target_id: id, status: :pending })
  end

  def outgoing_contact_requests
    User.joins(:incoming_contacts).where(incoming_contacts: { creator_id: id, status: :pending })
  end

  def contacts
    User.joins(:incoming_contacts).where(incoming_contacts: { creator_id: id, status: :accepted })
        .union(User.joins(:outgoing_contacts).where(outgoing_contacts: { target_id: id, status: :accepted }))
  end

  def find_contact(contact_user_id)
    Contact.where(creator_id: id, target_id: contact_user_id)
           .or(Contact.where(creator_id: contact_user_id, target_id: id)).first
  end

  protected

  def email_required?        = !system?
  def password_required?     = (!persisted? || !password.nil? || !password_confirmation.nil?) && !system?
  def confirmation_required? = !system?
end
