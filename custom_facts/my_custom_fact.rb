# frozen_string_literal: true

Facter.add(:my_custom_fact) do
  confine osfamily: 'Darwin'
  has_weight(10_000)
  setcode do
    'my_custom_fact'
  end
end
