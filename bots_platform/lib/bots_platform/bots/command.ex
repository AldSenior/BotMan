defmodule BotsPlatform.Bots.Command do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "commands" do
    field :name, :string
    field :description, :string
    field :trigger, :string
    field :response_type, Ecto.Enum, values: [:text, :image, :document, :keyboard]
    field :response_content, :string
    field :is_active, :boolean, default: true

    belongs_to :bot, BotsPlatform.Bots.Bot

    timestamps()
  end

  def changeset(command, attrs) do
    attrs =
      if is_binary(attrs["response_type"]) || is_binary(attrs[:response_type]) do
        Map.update!(attrs, :response_type, &String.downcase/1)
      else
        attrs
      end

    command
    |> cast(attrs, [
      :name,
      :description,
      :trigger,
      :response_type,
      :response_content,
      :is_active,
      :bot_id
    ])
    |> validate_required([:name, :trigger, :response_type, :response_content, :bot_id])
    |> foreign_key_constraint(:bot_id)
  end
end
