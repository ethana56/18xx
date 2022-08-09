# frozen_string_literal: true

require_relative '../../../step/base'
require_relative '../../../step/buy_train'

module Engine
  module Game
    module G1848
      module Step
        class BuyTrain < Engine::Step::BuyTrain
          def buy_train_action(action, entity = nil, borrow_from: nil)
            entity ||= action.entity
            price = action.price
            remaining = price - buying_power(entity)

            if remaining.positive? && !@game.round.actions_for(entity).include?('pass')
              # do emergency loan
              if @game.round.actions_for(entity).include?('take_loan')
                raise GameError,
                      "#{entity.name} can take a regular loan, prior to performing Compulsory Train Purchase"
              end

              @game.perform_ebuy_loans(entity, remaining)
            end
            return if entity.share_price.price.zero? # company is closing, not buying train

            super
          end

          def can_entity_buy_train?(entity)
            return false if entity == @game.boe

            super
          end

          def buyable_trains(entity)
            # Cannot buy 2E if one is already owned, can't by non 2e if at limit
            trains_to_buy = at_train_limit?(entity) ? [] : super
            trains_to_buy = trains_to_buy.select(&:from_depot?) unless @game.can_buy_trains
            trains_to_buy = reject_unaffordable_depot_trains(trains_to_buy, entity) if must_buy_train?(entity)
            if owns_2e?(entity)
              trains_to_buy = trains_to_buy.reject { |t| t.name == '2E' }
            elsif trains_to_buy.none? { |t| t.name == '2E' } && can_buy_2e?(entity)
              trains_to_buy << ghan_train
            end
            trains_to_buy.uniq
          end

          def reject_unaffordable_depot_trains(trains_to_buy, entity)
            trains_to_buy.reject { |train| @depot.discarded.include?(train) && train.price > buying_power(entity) }
          end

          def owns_2e?(entity)
            entity.trains.any? { |t| t.name == '2E' }
          end

          def can_buy_2e?(entity)
            return false if !@game.phase.available?(ghan_train&.available_on) || owns_2e?(entity)

            cost = ghan_train.price
            cost -= ghan_private_ability.discount if ghan_private_owned?(entity)
            cost <= entity.cash
          end

          def ghan_private_ability
            @ghan_private_ability ||= @game.abilities(@game.ghan, :train_discount, time: ability_timing)
          end

          def ghan_train
            @depot.depot_trains.find { |t| t.name == '2E' }
          end

          def ghan_private_owned?(entity)
            entity.companies.include?(@game.ghan) || entity.owner.companies.include?(@game.ghan)
          end

          def at_train_limit?(entity)
            entity.trains.count { |t| t.name != '2E' } == @game.train_limit(entity)
          end

          def room?(entity)
            !at_train_limit?(entity) || can_buy_2e?(entity)
          end

          def spend_minmax(entity, train)
            return [1, buying_power(entity)] if train.owner.owner == entity.owner

            [train.price, train.price]
          end

          def can_ebuy_sell_shares?(_entity)
            false
          end

          def must_take_loan?(_entity)
            true
          end
        end
      end
    end
  end
end
