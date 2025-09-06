<?php
use Magento\Framework\App\Bootstrap;
use Magento\Store\Model\StoreManagerInterface;
use Magento\Store\Api\WebsiteRepositoryInterface;
use Magento\Store\Api\GroupRepositoryInterface;
use Magento\Store\Api\Data\WebsiteInterfaceFactory;
use Magento\Store\Api\Data\GroupInterfaceFactory;
use Magento\Store\Api\Data\StoreInterfaceFactory;
use Magento\Config\Model\ResourceModel\Config as ResourceConfig;

require __DIR__ . '/../src/app/bootstrap.php';

$params = $_SERVER;
$bootstrap = Bootstrap::create(BP, $params);
$objectManager = $bootstrap->getObjectManager();

/** @var StoreManagerInterface $storeManager */
$storeManager = $objectManager->get(StoreManagerInterface::class);
/** @var WebsiteRepositoryInterface $websiteRepo */
$websiteRepo = $objectManager->get(WebsiteRepositoryInterface::class);
/** @var GroupRepositoryInterface $groupRepo */
$groupRepo = $objectManager->get(GroupRepositoryInterface::class);
/** @var WebsiteInterfaceFactory $websiteFactory */
$websiteFactory = $objectManager->get(WebsiteInterfaceFactory::class);
/** @var GroupInterfaceFactory $groupFactory */
$groupFactory = $objectManager->get(GroupInterfaceFactory::class);
/** @var StoreInterfaceFactory $storeFactory */
$storeFactory = $objectManager->get(StoreInterfaceFactory::class);
/** @var ResourceConfig $resourceConfig */
$resourceConfig = $objectManager->get(ResourceConfig::class);

$websites = [
    [
        'code' => 'uae',
        'name' => 'UAE',
        'currency' => 'AED',
        'host' => 'uae.localhost',
        'locales' => [
            'en' => 'en_US',
            'ar' => 'ar_SA'
        ]
    ],
    [
        'code' => 'ksa',
        'name' => 'KSA',
        'currency' => 'SAR',
        'host' => 'ksa.localhost',
        'locales' => [
            'en' => 'en_US',
            'ar' => 'ar_SA'
        ]
    ],
    [
        'code' => 'oman',
        'name' => 'Oman',
        'currency' => 'OMR',
        'host' => 'oman.localhost',
        'locales' => [
            'en' => 'en_US',
            'ar' => 'ar_SA'
        ]
    ],
    [
        'code' => 'kuwait',
        'name' => 'Kuwait',
        'currency' => 'KWD',
        'host' => 'kuwait.localhost',
        'locales' => [
            'en' => 'en_US',
            'ar' => 'ar_SA'
        ]
    ],
];

$allowedCurrencies = 'AED,SAR,OMR,KWD';

/** Create or update websites, store groups and views */
foreach ($websites as $w) {
    $website = null;
    try {
        $website = $websiteRepo->get($w['code']);
        echo "Website {$w['code']} exists\n";
    } catch (\Magento\Framework\Exception\NoSuchEntityException $e) {
        $website = $websiteFactory->create();
        $website->setCode($w['code']);
        $website->setName($w['name']);
        $website->setIsDefault(false);
        $websiteRepo->save($website);
        echo "Website {$w['code']} created\n";
    }

    // Store Group (aka Store)
    $groupCode = $w['code'] . '_store';
    $group = null;
    $groups = $website->getGroups();
    foreach ($groups as $g) {
        if ($g->getCode() === $groupCode) { $group = $g; break; }
    }
    if (!$group) {
        $group = $groupFactory->create();
        $group->setCode($groupCode);
        $group->setName($w['name'] . ' Store');
        $group->setWebsiteId((int)$website->getId());
        $group->setRootCategoryId(2); // Default Root Category
        $groupRepo->save($group);
        echo "Group {$groupCode} created\n";
    } else {
        echo "Group {$groupCode} exists\n";
    }

    // Store Views: en and ar (codes must be globally unique)
    $enStoreId = null;
    foreach (['en','ar'] as $lang) {
        $storeCode = $w['code'] . '_' . $lang;
        $store = null;
        try {
            $store = $storeManager->getStore($storeCode);
        } catch (\Magento\Framework\Exception\NoSuchEntityException $e) {
            $store = null;
        }
        if (!$store || !$store->getId()) {
            $store = $storeFactory->create();
            $store->setCode($storeCode);
            $store->setName($w['name'] . ' ' . strtoupper($lang));
            $store->setWebsiteId((int)$website->getId());
            $store->setGroupId((int)$group->getId());
            $store->setIsActive(true);
            $store->save();
            echo "Store view {$storeCode} created\n";
        } else {
            echo "Store view {$storeCode} exists\n";
        }

        // Set locale per store view
        $resourceConfig->saveConfig('general/locale/code', $w['locales'][$lang], 'stores', (int)$store->getId());

        if ($lang === 'en') {
            $enStoreId = (int)$store->getId();
        }
    }

    // Set default store view of the group to English
    if ($enStoreId && (int)$group->getDefaultStoreId() !== $enStoreId) {
        $group->setDefaultStoreId($enStoreId);
        $groupRepo->save($group);
        echo "Default store view for {$groupCode} set to EN\n";
    }

    // Set default group for website if not set
    if ((int)$website->getDefaultGroupId() !== (int)$group->getId()) {
        $website->setDefaultGroupId((int)$group->getId());
        $websiteRepo->save($website);
        echo "Default group set for website {$w['code']}\n";
    }

    // Set configs: currency, locale, allowed currencies, base URLs
    $scope = 'websites';
    $scopeId = (int)$website->getId();

    $resourceConfig->saveConfig('currency/options/base', $w['currency'], $scope, $scopeId);
    $resourceConfig->saveConfig('currency/options/default', $w['currency'], $scope, $scopeId);
    $resourceConfig->saveConfig('currency/options/allow', $allowedCurrencies, $scope, $scopeId);

    // Base URLs: per-website using subdomains, language segment handled via Nginx rewrites
    $baseUrl = 'http://' . $w['host'] . '/';
    $baseUrlSecure = 'https://' . $w['host'] . '/';
    $resourceConfig->saveConfig('web/unsecure/base_url', $baseUrl, $scope, $scopeId);
    $resourceConfig->saveConfig('web/secure/base_url', $baseUrlSecure, $scope, $scopeId);
}

// Global config: do NOT use store code in URLs; SEO rewrites ON
$resourceConfig->saveConfig('web/url/use_store', 0, 'default', 0);
$resourceConfig->saveConfig('web/seo/use_rewrites', 1, 'default', 0);

// Flush config cache programmatically
$cacheManager = $objectManager->get(\Magento\Framework\App\Cache\TypeListInterface::class);
foreach ($cacheManager->getTypes() as $type) {
    $cacheManager->cleanType($type);
}

echo "Done creating stores.\n";
