// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract AutomatedSubscriptionSystem {
    using SafeMath for uint256;

    struct Subscription {
        string productName;
        string description;
        string link;
        uint256 amount;
        uint256 intervalInSeconds;
        uint256 lastPayment;
        bool active;
    }

    mapping(address => mapping(uint256 => Subscription)) public subscriptions; // Provider -> Subscription ID -> Subscription
    mapping(address => uint256) public subscriptionCount; // Provider -> Subscription Count
    mapping(address => mapping(uint256 => address[])) public activeSubscribers; // Provider -> Subscription ID -> Subscribers
    mapping(address => uint256[]) public activeSubscriptions; // Provider -> Active Subscription IDs
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public subscriberLastPayment; // Provider -> Subscription ID -> Subscriber -> Last Payment
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public subscriberTotalPayments; // Provider -> Subscription ID -> Subscriber -> Total Payments
    mapping(address => bool) public isProvider; // Tracks if an address is a provider
    address[] public allProviders; // List of all providers
    mapping(address => bool) public countedUsers; // Tracks if an address has been counted as a user
    mapping(address => mapping(uint256 => mapping(address => bool)))
        public paymentFailure; // Provider -> Subscription ID -> Subscriber -> Payment Failure Status
    // Mapping to track if a user is subscribed or unsubscribed
    mapping(address => bool) public isUnsubscribed; // Tracks unsubscribed users globally
    mapping(address => bool) public allUsers;

    IERC20 public paymentToken;

    event SubscriptionCreated(address provider, uint256 subscriptionId);
    event Subscribed(
        address subscriber,
        address provider,
        uint256 subscriptionId
    );
    event Unsubscribed(
        address subscriber,
        address provider,
        uint256 subscriptionId
    );
    event PaymentProcessed(
        address subscriber,
        address provider,
        uint256 subscriptionId,
        uint256 amount
    );
    event PaymentFailed(
        address subscriber,
        address provider,
        uint256 subscriptionId,
        string reason
    );

    constructor(address _paymentToken) {
        paymentToken = IERC20(_paymentToken);
    }

    function createSubscription(
        string memory _productName,
        string memory _description,
        string memory _link,
        uint256 _amount,
        uint256 _intervalInSeconds
    ) external {
        uint256 subscriptionId = subscriptionCount[msg.sender];
        subscriptions[msg.sender][subscriptionId] = Subscription({
            productName: _productName,
            description: _description,
            link: _link,
            amount: _amount,
            intervalInSeconds: _intervalInSeconds,
            lastPayment: 0,
            active: true
        });

        if (!isProvider[msg.sender]) {
            isProvider[msg.sender] = true;
            allProviders.push(msg.sender);
        }

        activeSubscriptions[msg.sender].push(subscriptionId);
        subscriptionCount[msg.sender] = subscriptionId.add(1);
        emit SubscriptionCreated(msg.sender, subscriptionId);
    }

    function subscribe(address provider, uint256 subscriptionId) external {
        Subscription storage sub = subscriptions[provider][subscriptionId];
        require(sub.active, "Subscription is not active");
        require(
            paymentToken.transferFrom(msg.sender, provider, sub.amount),
            "Payment failed"
        );

        subscriberLastPayment[provider][subscriptionId][msg.sender] = block
            .timestamp;
        subscriberTotalPayments[provider][subscriptionId][msg.sender] += sub
            .amount;
        activeSubscribers[provider][subscriptionId].push(msg.sender);

        // Mark the subscriber as a counted user
        markUserAsCounted(msg.sender);

        emit Subscribed(msg.sender, provider, subscriptionId);
    }

    function unsubscribe(address provider, uint256 subscriptionId) external {
    Subscription storage sub = subscriptions[provider][subscriptionId];
    require(sub.active, "Subscription is not active");

    // Remove subscriber from the list
    address[] storage subscribers = activeSubscribers[provider][subscriptionId];
    for (uint256 i = 0; i < subscribers.length; i++) {
        if (subscribers[i] == msg.sender) {
            subscribers[i] = subscribers[subscribers.length - 1];
            subscribers.pop();
            break;
        }
    }

    // Update subscriber state
    subscriberLastPayment[provider][subscriptionId][msg.sender] = 0;

    emit Unsubscribed(msg.sender, provider, subscriptionId);
}

    function checkAndProcessPayments() external {
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];

            for (uint256 j = 0; j < activeSubscriptions[provider].length; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                Subscription storage sub = subscriptions[provider][
                    subscriptionId
                ];

                if (!sub.active) continue;

                for (
                    uint256 k = 0;
                    k < activeSubscribers[provider][subscriptionId].length;
                    k++
                ) {
                    address subscriber = activeSubscribers[provider][
                        subscriptionId
                    ][k];

                    uint256 lastPayment = subscriberLastPayment[provider][
                        subscriptionId
                    ][subscriber];
                    uint256 paymentsDue = (block.timestamp - lastPayment) /
                        sub.intervalInSeconds;

                    for (uint256 l = 0; l < paymentsDue; l++) {
                        bool paymentSuccess = paymentToken.transferFrom(
                            subscriber,
                            provider,
                            sub.amount
                        );
                        if (paymentSuccess) {
                            lastPayment = lastPayment.add(
                                sub.intervalInSeconds
                            );
                            subscriberTotalPayments[provider][subscriptionId][
                                subscriber
                            ] += sub.amount;
                            emit PaymentProcessed(
                                subscriber,
                                provider,
                                subscriptionId,
                                sub.amount
                            );
                            paymentFailure[provider][subscriptionId][
                                subscriber
                            ] = false; // Clear failure status
                        } else {
                            paymentFailure[provider][subscriptionId][
                                subscriber
                            ] = true;
                            emit PaymentFailed(
                                subscriber,
                                provider,
                                subscriptionId,
                                "Payment failed"
                            );
                        }
                    }

                    subscriberLastPayment[provider][subscriptionId][
                        subscriber
                    ] = lastPayment;
                }
            }
        }
    }

    function getPaymentFailureStatus(
        address provider,
        uint256 subscriptionId,
        address subscriber
    ) external view returns (bool) {
        return paymentFailure[provider][subscriptionId][subscriber];
    }

    function getSubscriberPayments(
        address provider,
        uint256 subscriptionId,
        address subscriber
    ) external view returns (uint256) {
        return subscriberTotalPayments[provider][subscriptionId][subscriber];
    }

    // Analytics for Subscription Provider
    function getProviderTotalPayments(address provider)
        external
        view
        returns (uint256 totalPayments)
    {
        for (uint256 i = 0; i < activeSubscriptions[provider].length; i++) {
            uint256 subscriptionId = activeSubscriptions[provider][i];
            for (
                uint256 j = 0;
                j < activeSubscribers[provider][subscriptionId].length;
                j++
            ) {
                address subscriber = activeSubscribers[provider][
                    subscriptionId
                ][j];
                totalPayments = totalPayments.add(
                    subscriberTotalPayments[provider][subscriptionId][
                        subscriber
                    ]
                );
            }
        }
    }

    function getActiveSubscribersCount(address provider, uint256 subscriptionId)
        external
        view
        returns (uint256)
    {
        return activeSubscribers[provider][subscriptionId].length;
    }

    function getTotalActiveSubscriptions(address provider)
        external
        view
        returns (uint256)
    {
        return activeSubscriptions[provider].length;
    }

    function getTotalAmountEarned(address provider, uint256 subscriptionId)
        external
        view
        returns (uint256 totalAmount)
    {
        for (
            uint256 i = 0;
            i < activeSubscribers[provider][subscriptionId].length;
            i++
        ) {
            address subscriber = activeSubscribers[provider][subscriptionId][i];
            totalAmount = totalAmount.add(
                subscriberTotalPayments[provider][subscriptionId][subscriber]
            );
        }
    }

    // Analytics for Subscriber
    function getSubscriberTotalPayments(address subscriber)
        external
        view
        returns (uint256 totalPayments)
    {
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            for (uint256 j = 0; j < activeSubscriptions[provider].length; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                totalPayments = totalPayments.add(
                    subscriberTotalPayments[provider][subscriptionId][
                        subscriber
                    ]
                );
            }
        }
    }

    function getSubscriberActiveSubscriptions(address subscriber)
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            for (uint256 j = 0; j < activeSubscriptions[provider].length; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                for (
                    uint256 k = 0;
                    k < activeSubscribers[provider][subscriptionId].length;
                    k++
                ) {
                    if (
                        activeSubscribers[provider][subscriptionId][k] ==
                        subscriber
                    ) {
                        count++;
                        break;
                    }
                }
            }
        }
    }

    function getLastPaymentForSubscription(
        address provider,
        uint256 subscriptionId,
        address subscriber
    ) external view returns (uint256 lastPayment) {
        return subscriberLastPayment[provider][subscriptionId][subscriber];
    }

    // Platform-wide Analytics
    function getTotalActiveProviders() external view returns (uint256) {
        return allProviders.length;
    }

    function getTotalSubscriptions()
        external
        view
        returns (uint256 totalSubscriptions)
    {
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            totalSubscriptions = totalSubscriptions.add(
                activeSubscriptions[provider].length
            );
        }
    }

    function getTotalActiveSubscribers()
        external
        view
        returns (uint256 totalSubscribers)
    {
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            for (uint256 j = 0; j < activeSubscriptions[provider].length; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                totalSubscribers = totalSubscribers.add(
                    activeSubscribers[provider][subscriptionId].length
                );
            }
        }
    }

    function getTotalAmountProcessed()
        external
        view
        returns (uint256 totalProcessed)
    {
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            for (uint256 j = 0; j < activeSubscriptions[provider].length; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                for (
                    uint256 k = 0;
                    k < activeSubscribers[provider][subscriptionId].length;
                    k++
                ) {
                    address subscriber = activeSubscribers[provider][
                        subscriptionId
                    ][k];
                    totalProcessed = totalProcessed.add(
                        subscriberTotalPayments[provider][subscriptionId][
                            subscriber
                        ]
                    );
                }
            }
        }
    }

    // Function to mark a user as counted
    function markUserAsCounted(address user) internal {
        countedUsers[user] = true;
    }

    // Function to update the count of unique users
    function updateUserCount() external {
        // Reset the countedUsers mapping
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            countedUsers[provider] = false;
            for (uint256 j = 0; j < activeSubscriptions[provider].length; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                for (uint256 k = 0; k < activeSubscribers[provider][subscriptionId].length; k++) {
                    address subscriber = activeSubscribers[provider][subscriptionId][k];
                    countedUsers[subscriber] = false;
                }
            }
        }

        // Count all providers
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            countedUsers[provider] = true;
        }

        // Count all subscribers
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            for (uint256 j = 0; j < activeSubscriptions[provider].length; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                for (uint256 k = 0; k < activeSubscribers[provider][subscriptionId].length; k++) {
                    address subscriber = activeSubscribers[provider][subscriptionId][k];
                    countedUsers[subscriber] = true;
                }
            }
        }
    }

    // Function to get the total number of unique users on the platform
    function getTotalUsers() external view returns (uint256) {
        uint256 totalUsers = 0;

        // Count all providers
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            if (countedUsers[provider]) {
                totalUsers++;
            }
        }

        // Count all subscribers
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            for (uint256 j = 0; j < activeSubscriptions[provider].length; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                for (uint256 k = 0; k < activeSubscribers[provider][subscriptionId].length; k++) {
                    address subscriber = activeSubscribers[provider][subscriptionId][k];
                    if (countedUsers[subscriber]) {
                        totalUsers++;
                    }
                }
            }
        }

        return totalUsers;
    }

    function getAllSubscriptions()
        external
        view
        returns (address[] memory, Subscription[][] memory)
    {
        uint256 providerCount = allProviders.length;

        // Create arrays to hold the result
        address[] memory providers = new address[](providerCount);
        Subscription[][] memory providerSubscriptions = new Subscription[][](
            providerCount
        );

        for (uint256 i = 0; i < providerCount; i++) {
            address provider = allProviders[i];
            providers[i] = provider;

            uint256 subscriptionCountForProvider = activeSubscriptions[provider]
                .length;
            Subscription[] memory subscriptionsForProvider = new Subscription[](
                subscriptionCountForProvider
            );

            for (uint256 j = 0; j < subscriptionCountForProvider; j++) {
                uint256 subscriptionId = activeSubscriptions[provider][j];
                subscriptionsForProvider[j] = subscriptions[provider][
                    subscriptionId
                ];
            }

            providerSubscriptions[i] = subscriptionsForProvider;
        }

        return (providers, providerSubscriptions);
    }

}
