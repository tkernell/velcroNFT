import { log, Bytes } from '@graphprotocol/graph-ts';
import {
  PlanController
} from '../types/schema';

import {
 SubscriptionCreated as SubscriptionCreatedEvent,
 SubscriptionFunded as SubscriptionFundedEvent,
} from '../types/PlanController/PlanController';

export function handleSubscriptionCreated(event: SubscriptionCreatedEvent): void {
  let planController = PlanController.load(event.address.toHexString());

  if (planController != null) {
      // update controller
      planController.save();
  }
}

export function handleSubscriptionFunded(event: SubscriptionFundedEvent): void {
  let planController = PlanController.load(event.address.toHexString());

  if (planController != null) {
      // update controller
      planController.save();
  }
}
