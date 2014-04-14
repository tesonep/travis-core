class Build

  # The build's start and finish events (state changes) trigger denormalization
  # of certain attributes to the repository in order to disburden the db a bit.
  #
  # E.g. on `start` the `started_at` attribute of a build gets set to its
  # repository's `last_started_at` attribute. Likewise on `finish` the
  # `finished_at` and `state` attributes are set to `last_build_finished_at` and
  # `last_build_state` on the repository.
  #
  # These attributes are used in the repositories list and thus read frequently.
  module Denormalize
    def denormalize(event, *args)
      if denormalize?(event)
        repository.update_attributes!(denormalize_attributes_for(event))
        branches.each { |branch|
          branch.update_attributes!(denormalize_attributes_for(event))
        }
        tags.each { |tag|
          tag.update_attributes!(denormalize_attributes_for(event))
        }
      end
    end

    DENORMALIZE = {
      start:  %w(id number state duration started_at finished_at),
      finish: %w(state duration finished_at),
      reset:  %w(state duration started_at finished_at),
      cancel: %w(state duration finished_at)
    }

    def denormalize?(event)
      DENORMALIZE.key?(event)
    end

    def denormalize_attributes_for(event)
      DENORMALIZE[event].inject({}) do |result, key|
        result.merge(:"last_build_#{key}" => send(key))
      end
    end
  end
end
