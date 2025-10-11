const { Hyperliquid } = require("hyperliquid");
const Redis = require("ioredis");

const hypeSdk = new Hyperliquid({
  privateKey: process.env.PRIVATE_KEY,
  testnet: false, // Changed to mainnet for real orders
  enableWs: true,
});

let redisClient;
const getRedisClient = () => {
  if (!redisClient) {
    try {
      const redisUrl = process.env.REDIS_URL;
      redisClient = new Redis(redisUrl, {
        maxRetriesPerRequest: null,
      });
      console.log("Redis client initialized");
    } catch (error) {
      console.error("Failed to initialize Redis client:", error);
      throw error;
    }
  }
  return redisClient;
};

const getCoinValue = async (coin) => {
  try {
    const redisClient = getRedisClient();
    const spotMidsKey = `mids:${coin}`;
    const coinValue = await redisClient.get(spotMidsKey);
    if (!coinValue) throw new Error(`No mids found for ${coin}`);
    const universe = JSON.parse(coinValue);
    return Number(universe);
  } catch (error) {
    console.error("Error fetching mids:", error);
    throw new Error(`Failed to ${coin} mids`);
  }
};

const getl2bookValue = async (coin) => {
  try {
    const redisClient = getRedisClient();
    const redisKey = `l2book:${coin}`;
    const coinValue = await redisClient.get(redisKey);
    if (!coinValue) throw new Error(`No l2bookValue found for ${coin}`);
    const l2BookValue = JSON.parse(coinValue);
    return l2BookValue;
  } catch (error) {
    console.error(`Error fetching l2bookValue for ${coin}:`, error);
    throw new Error(`Failed to ${coin} l2bookValue`);
  }
};

const getUniverseValue = async (coin) => {
  try {
    const redisClient = getRedisClient();
    const redisKey = `universe:${coin}`;
    const coinValue = await redisClient.get(redisKey);
    if (!coinValue) throw new Error(`No universe found for ${coin}`);
    const universe = JSON.parse(coinValue);
    return universe;
  } catch (error) {
    console.error(`Error fetching universe for ${coin}:`, error);
    throw new Error(`Failed to ${coin} universe`);
  }
};

const getSzValues = (attempt, amount, book, universe, isPerp = true) => {
  try {
    const MAX_DECIMALS_PERP = 6;
    const MAX_DECIMALS_SPOT = 8;
    const bps = 15 + (attempt - 1) * 10;
    const bestAsk = parseFloat(book.levels[1][0].px);

    const tickSizeConfig = {
      ETH: 0.1,
      SOL: 0.01,
    };

    const tickSize = tickSizeConfig[universe.name];
    const szDecimals = universe.szDecimals || 4;
    const maxDecimals = isPerp ? MAX_DECIMALS_PERP : MAX_DECIMALS_SPOT;
    const maxAllowedPxDecimals = maxDecimals - szDecimals;

    const rawPx = bestAsk * (1 + bps / 10000);
    let limit_px = Math.floor(rawPx / tickSize) * tickSize;

    const limit_px_str = limit_px.toFixed(12);
    const [intPart, decPart = ""] = limit_px_str.split(".");
    const trimmedDecimals = decPart.slice(0, maxAllowedPxDecimals);
    limit_px = parseFloat(`${intPart}.${trimmedDecimals}`.replace(/\.$/, ""));

    let limit_px_fixed = parseFloat(limit_px.toPrecision(5));
    if (limit_px_fixed % tickSize !== 0) {
      limit_px_fixed = Math.floor(limit_px_fixed / tickSize) * tickSize;
    }

    limit_px = parseFloat(limit_px_fixed.toFixed(8));
    const sz = parseFloat(amount.toFixed(szDecimals));

    limit_px = Math.floor(limit_px / tickSize) * tickSize;

    return { limit_px, sz };
  } catch (error) {
    console.error("Error fetching limit_px and sz:", error);
    throw new Error("Failed to compute order price and size");
  }
};

const placeIocPerpOrder = async (coin, sz, limit_px) => {
  const minOrderSize = 0.001;
  if (sz < minOrderSize) {
    throw new Error(
      `Order size ${sz} is below minimum order size ${minOrderSize}`
    );
  }

  const coinSymbol = `${coin}-PERP`;

  const orderRequest = {
    coin: coinSymbol,
    is_buy: true,
    sz: sz,
    limit_px: limit_px,
    order_type: { limit: { tif: "Ioc" } },
    reduce_only: false,
  };

  console.log(`Order request: ${JSON.stringify(orderRequest, null, 2)}`);

  try {
    const result = await hypeSdk.wsPayloads.placeOrder(orderRequest);
    console.log(`Order placed successfully!`);
    return result;
  } catch (error) {
    console.error("Order placement failed!");
    console.log({
      message: error.message,
      code: error.code,
      data: error.data,
      stack: error.stack,
    });
    throw error;
  }
};

const calculateHedgeAmount = (totalUsdValue, coinUsd) =>
  Number((totalUsdValue / coinUsd).toFixed(4));

// --- NEW: Helper to measure duration ---
const measureExecutionTime = async (fn) => {
  const start = Date.now();
  const result = await fn();
  const end = Date.now();
  return { result, duration: end - start };
};

// --- TEST EXECUTION with timing ---
const testExecution = async () => {
  const region = process.env.REGION || 'unknown';
  const timestamp = new Date().toISOString();
  
  console.log("=".repeat(60));
  console.log(`Starting latency test execution`);
  console.log(`Region: ${region}`);
  console.log(`Timestamp: ${timestamp}`);
  console.log("=".repeat(60));
  
  await hypeSdk.ws.connect();

  const ordersToExecute = [
    { coin: "SOL", amount: 15 }, // $15 order value (above $11 minimum)
    { coin: "ETH", amount: 15 }, // $15 order value (above $11 minimum)
  ];

  const executionTimes = [];
  const detailedResults = [];

  for (const order of ordersToExecute) {
    const { coin, amount: totalUsdValue } = order;
    console.log(`\n--- Processing order for ${coin} ---`);

    const startTime = Date.now();
    const stepTimes = {};

    try {
      // Step 1: Data fetching
      const dataStart = Date.now();
      const [coinUsd, l2BookValue, universeValue] = await Promise.all([
        getCoinValue(coin),
        getl2bookValue(coin),
        getUniverseValue(coin),
      ]);
      stepTimes.dataFetch = Date.now() - dataStart;

      // Step 2: Amount calculation
      const calcStart = Date.now();
      const totalAmount = calculateHedgeAmount(totalUsdValue, coinUsd);
      stepTimes.calculation = Date.now() - calcStart;
      console.log(`Calculated hedge amount for ${coin}: ${totalAmount}`);

      // Step 3: Order parameters calculation
      const paramsStart = Date.now();
      const { limit_px, sz } = getSzValues(
        1,
        totalAmount,
        l2BookValue,
        universeValue
      );
      stepTimes.paramsCalculation = Date.now() - paramsStart;
      console.log(`Calculated sz: ${sz}, limit_px: ${limit_px}`);

      // Step 4: Order placement
      const { duration: orderDuration } = await measureExecutionTime(() =>
        placeIocPerpOrder(coin, sz, limit_px)
      );
      stepTimes.orderPlacement = orderDuration;

      const totalDuration = Date.now() - startTime;
      
      const orderResult = {
        coin,
        totalDuration,
        stepTimes,
        success: true,
        error: null
      };
      
      detailedResults.push(orderResult);
      executionTimes.push(totalDuration);
      
      console.log(`\n--- ${coin} Execution Breakdown ---`);
      console.log(`Data fetch: ${stepTimes.dataFetch} ms`);
      console.log(`Calculation: ${stepTimes.calculation} ms`);
      console.log(`Params calculation: ${stepTimes.paramsCalculation} ms`);
      console.log(`Order placement: ${stepTimes.orderPlacement} ms`);
      console.log(`Total execution: ${totalDuration} ms`);
      
    } catch (error) {
      const totalDuration = Date.now() - startTime;
      const orderResult = {
        coin,
        totalDuration,
        stepTimes: {},
        success: false,
        error: error.message
      };
      
      detailedResults.push(orderResult);
      executionTimes.push(totalDuration);
      
      console.error(`Failed to process order for ${coin}:`, error.message);
    }
  }

  const totalLatency = executionTimes.reduce((a, b) => a + b, 0);
  const avgLatency =
    executionTimes.length > 0 ? totalLatency / executionTimes.length : 0;

  console.log("\n" + "=".repeat(60));
  console.log("=== EXECUTION SUMMARY ===");
  console.log(`Region: ${region}`);
  console.log(`Test completed at: ${new Date().toISOString()}`);
  console.log(`Total orders processed: ${ordersToExecute.length}`);
  console.log(`Successful orders: ${detailedResults.filter(r => r.success).length}`);
  console.log(`Failed orders: ${detailedResults.filter(r => !r.success).length}`);
  console.log(`Individual order latencies (ms): ${executionTimes.join(", ")}`);
  console.log(`Average latency: ${avgLatency.toFixed(2)} ms`);
  
  // Calculate step-wise averages
  const avgStepTimes = {};
  const successfulResults = detailedResults.filter(r => r.success);
  
  if (successfulResults.length > 0) {
    ['dataFetch', 'calculation', 'paramsCalculation', 'orderPlacement'].forEach(step => {
      const stepValues = successfulResults.map(r => r.stepTimes[step]).filter(v => v !== undefined);
      if (stepValues.length > 0) {
        avgStepTimes[step] = (stepValues.reduce((a, b) => a + b, 0) / stepValues.length).toFixed(2);
      }
    });
    
    console.log("\n--- Average Step Times ---");
    console.log(`Data fetch: ${avgStepTimes.dataFetch || 'N/A'} ms`);
    console.log(`Calculation: ${avgStepTimes.calculation || 'N/A'} ms`);
    console.log(`Params calculation: ${avgStepTimes.paramsCalculation || 'N/A'} ms`);
    console.log(`Order placement: ${avgStepTimes.orderPlacement || 'N/A'} ms`);
  }
  
  console.log("=".repeat(60));

  // Cleanup
  const redis = getRedisClient();
  if (redis) redis.disconnect();
  if (hypeSdk.ws.ws.readyState === 1) hypeSdk.ws.close();
  console.log("Test execution finished.");
};

testExecution();
