class CreateFeedbacks < ActiveRecord::Migration[5.1]
  def change
    create_table :feedbacks do |t|
      t.text :text
      t.references :assignment

      t.timestamps
    end
  end
end
