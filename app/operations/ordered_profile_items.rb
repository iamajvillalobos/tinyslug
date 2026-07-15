class OrderedProfileItems
  DIRECTIONS = { up: -1, down: 1 }.freeze

  def self.append(record:, profile:)
    record.class.transaction do
      profile.lock!
      record.position = record.class.where(profile:).maximum(:position).to_i + 1
      record.position = 0 unless record.class.where(profile:).exists?
      record.save
    end
    record
  end

  def self.move(record:, profile:, direction:)
    offset = DIRECTIONS.fetch(direction)

    record.class.transaction do
      profile.lock!
      records = record.class.where(profile:).order(:position, :id).lock.to_a
      current_index = records.index { |item| item.id == record.id }
      raise ActiveRecord::RecordNotFound unless current_index

      target_index = current_index + offset
      records[current_index], records[target_index] = records[target_index], records[current_index] if target_index.between?(0, records.length - 1)
      persist_positions(records)
    end
    record
  end

  def self.destroy(record:, profile:)
    record.class.transaction do
      profile.lock!
      record.destroy!
      persist_positions(record.class.where(profile:).order(:position, :id).lock.to_a)
    end
  end

  def self.persist_positions(records)
    records.each_with_index do |record, position|
      record.update_column(:position, position) unless record.position == position
    end
  end
  private_class_method :persist_positions
end
