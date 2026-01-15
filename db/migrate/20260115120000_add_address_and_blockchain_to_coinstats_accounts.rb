class AddAddressAndBlockchainToCoinstatsAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :coinstats_accounts, :address, :string
    add_column :coinstats_accounts, :blockchain, :string

    # Add index for the new uniqueness constraint
    add_index :coinstats_accounts, [ :coinstats_item_id, :account_id, :address, :blockchain ],
              unique: true,
              name: "index_coinstats_accounts_on_item_token_and_wallet",
              where: "account_id IS NOT NULL AND address IS NOT NULL AND blockchain IS NOT NULL"

    # Remove old index on account_id since we're changing the uniqueness constraint
    remove_index :coinstats_accounts, :account_id

    reversible do |dir|
      dir.up do
        # Backfill address and blockchain from raw_payload for existing records
        execute <<-SQL
          UPDATE coinstats_accounts
          SET
            address = raw_payload->>'address',
            blockchain = raw_payload->>'blockchain'
          WHERE raw_payload IS NOT NULL
            AND raw_payload->>'address' IS NOT NULL
            AND raw_payload->>'blockchain' IS NOT NULL
        SQL
      end
    end
  end
end
