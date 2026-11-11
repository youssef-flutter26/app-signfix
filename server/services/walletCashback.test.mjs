import { beforeAll, describe, expect, it, vi } from "vitest";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);

const mockQuery = vi.fn();
const mockClientQuery = vi.fn();
const mockClient = {
  query: mockClientQuery,
  release: vi.fn(),
};

require.cache[require.resolve("../mysqlPool")] = {
  id: require.resolve("../mysqlPool"),
  filename: require.resolve("../mysqlPool"),
  loaded: true,
  exports: {
    createPool: () => ({
      query: mockQuery,
      connect: vi.fn().mockResolvedValue(mockClient),
    }),
  },
};

process.env.DATABASE_URL = "mysql://test:test@127.0.0.1:3306/signfix";

const database = require("../database.js");

describe("SignFix Wallet & Cashback System", () => {
  it("has exactly 3 specifically configured promotional banners and Rs. 200 cashback", () => {
    expect(database.CASHBACK_AMOUNT).toBe(200);
    expect(database.CASHBACK_BANNER_IDS.size).toBe(3);
    expect(database.CASHBACK_BANNER_IDS.has("home_banner_1")).toBe(true);
    expect(database.CASHBACK_BANNER_IDS.has("home_banner_2")).toBe(true);
    expect(database.CASHBACK_BANNER_IDS.has("home_banner_3")).toBe(true);
    expect(database.CASHBACK_BANNER_IDS.has("other_banner")).toBe(false);
  });

  describe("previewWalletApplication", () => {
    it("correctly calculates when wallet balance is greater than order amount", async () => {
      mockQuery.mockImplementation(async (sql) => {
        if (sql.includes("FROM customers")) {
          return { rows: [{ id: 10 }] };
        }
        if (sql.includes("INSERT IGNORE INTO customer_wallets")) {
          return { rows: [] };
        }
        if (sql.includes("SELECT balance FROM customer_wallets")) {
          return { rows: [{ balance: "500.00" }] };
        }
        return { rows: [] };
      });

      const result = await database.previewWalletApplication(1, 200);
      expect(result.orderAmount).toBe(200);
      expect(result.walletBalance).toBe(500);
      expect(result.applicableWalletDebit).toBe(200);
      expect(result.remainingPayableAmount).toBe(0);
      expect(result.canApplyWallet).toBe(true);
    });

    it("correctly calculates when wallet balance is less than order amount", async () => {
      mockQuery.mockImplementation(async (sql) => {
        if (sql.includes("FROM customers")) {
          return { rows: [{ id: 10 }] };
        }
        if (sql.includes("INSERT IGNORE INTO customer_wallets")) {
          return { rows: [] };
        }
        if (sql.includes("SELECT balance FROM customer_wallets")) {
          return { rows: [{ balance: "200.00" }] };
        }
        return { rows: [] };
      });

      const result = await database.previewWalletApplication(1, 500);
      expect(result.orderAmount).toBe(500);
      expect(result.walletBalance).toBe(200);
      expect(result.applicableWalletDebit).toBe(200);
      expect(result.remainingPayableAmount).toBe(300);
      expect(result.canApplyWallet).toBe(true);
    });

    it("disables wallet payment when wallet balance is zero", async () => {
      mockQuery.mockImplementation(async (sql) => {
        if (sql.includes("FROM customers")) {
          return { rows: [{ id: 10 }] };
        }
        if (sql.includes("INSERT IGNORE INTO customer_wallets")) {
          return { rows: [] };
        }
        if (sql.includes("SELECT balance FROM customer_wallets")) {
          return { rows: [{ balance: "0.00" }] };
        }
        return { rows: [] };
      });

      const result = await database.previewWalletApplication(1, 500);
      expect(result.orderAmount).toBe(500);
      expect(result.walletBalance).toBe(0);
      expect(result.applicableWalletDebit).toBe(0);
      expect(result.remainingPayableAmount).toBe(500);
      expect(result.canApplyWallet).toBe(false);
    });
  });

  describe("getCustomerWallet", () => {
    it("returns formatted balance, total cashback earned, and transaction history", async () => {
      mockQuery.mockImplementation(async (sql) => {
        if (sql.includes("FROM customers")) {
          return { rows: [{ id: 10 }] };
        }
        if (sql.includes("INSERT IGNORE INTO customer_wallets")) {
          return { rows: [] };
        }
        if (sql.includes("SELECT id, balance, total_cashback_earned")) {
          return {
            rows: [
              {
                id: 1,
                balance: "200.00",
                totalCashbackEarned: "200.00",
                updatedAt: "2026-10-23T10:00:00Z",
              },
            ],
          };
        }
        if (sql.includes("FROM wallet_transactions")) {
          return {
            rows: [
              {
                transactionId: 101,
                orderId: 5,
                orderNo: "ORD-1001",
                type: "cashback_credit",
                amount: "200.00",
                previousBalance: "0.00",
                balanceAfter: "200.00",
                status: "successful",
                description: "Cashback ₹200 credited for promotional banner order home_banner_1",
                createdAt: "2026-10-23T10:00:00Z",
              },
            ],
          };
        }
        return { rows: [] };
      });

      const wallet = await database.getCustomerWallet(1);
      expect(wallet.customerId).toBe(10);
      expect(wallet.balance).toBe(200);
      expect(wallet.totalCashbackEarned).toBe(200);
      expect(wallet.eligibleBanners).toEqual([
        "home_banner_1",
        "home_banner_2",
        "home_banner_3",
      ]);
      expect(wallet.cashbackAmount).toBe(200);
      expect(wallet.transactions).toHaveLength(1);
      expect(wallet.transactions[0].amount).toBe(200);
      expect(wallet.transactions[0].previousBalance).toBe(0);
      expect(wallet.transactions[0].balanceAfter).toBe(200);
      expect(wallet.transactions[0].status).toBe("successful");
      expect(wallet.transactions[0].orderNo).toBe("ORD-1001");
    });
  });

  describe("order creation cashback & wallet rules", () => {
    it("credits cashback only for eligible promotional banners and applies wallet debit", async () => {
      const queries = [];
      database.calculatePrice = vi.fn().mockResolvedValue({
        estimatedPrice: 66000,
        area: 30,
        areaUnit: "ft",
        label: "Estimated Total",
        notice: "",
      });

      mockQuery.mockImplementation(async (sql) => {
        // debug
        if (sql.includes("FROM customers")) {
          return { rows: [{ id: 10, user_id: 1, name: "Test User", mobile: "9876543210" }] };
        }
        if (sql.toLowerCase().includes("products")) {
          return { rows: [{ pricing_method: "sqft", rate: 2200 }] };
        }
        if (sql.toLowerCase().includes("pricing_rules")) {
          return { rows: [] };
        }
        if (sql.includes("INSERT INTO audit_logs")) return { rows: [] };
        return { rows: [] };
      });

      mockClientQuery.mockImplementation(async (sql, params) => {
        queries.push({ sql, params });
        if (sql === "BEGIN" || sql === "COMMIT") return { rows: [] };
        if (sql.includes("INSERT IGNORE INTO customer_wallets")) return { rows: [] };
        if (sql.includes("SELECT id,balance,total_cashback_earned FROM customer_wallets")) {
          return { rows: [{ id: 99, balance: "150.00", total_cashback_earned: "0.00" }] };
        }
        if (sql.includes("INSERT INTO orders")) {
          return { insertId: 77 };
        }
        if (sql.includes("SELECT created_at FROM orders")) {
          return { rows: [{ created_at: new Date() }] };
        }
        if (sql.includes("INSERT INTO wallet_transactions")) {
          return { rows: [] };
        }
        if (sql.includes("UPDATE customer_wallets")) {
          return { rows: [] };
        }
        if (sql.includes("INSERT INTO order_status_history")) {
          return { rows: [] };
        }
        if (sql.includes("INSERT INTO audit_logs")) {
          return { rows: [] };
        }
        return { rows: [] };
      });

      const orderData = {
        product: "Acrylic LED Sign",
        length: 10,
        width: 3,
        quantity: 1,
        estimatedPrice: 66000,
        useWallet: true,
        promotionBannerId: "home_banner_1", // eligible
      };

      const result = await database.createOrder(
        { id: 1, role: "customer" },
        orderData,
        "ORD-2026-TEST",
      );

      // Result specifications should indicate cashback earned and wallet applied
      expect(result.cashbackEarned).toBe(200);
      expect(result.walletDiscountApplied).toBe(150);
      expect(result.finalEstimatedPrice).toBe(65850);

      // Check wallet_transactions insertions
      const debitInsert = queries.find(
        (q) => q.sql.includes("INSERT INTO wallet_transactions") && q.sql.includes("wallet_debit"),
      );
      expect(debitInsert).toBeDefined();
      expect(debitInsert.params).toContain(150); // amount
      expect(debitInsert.params).toContain(150); // previous balance
      expect(debitInsert.params).toContain(0);   // balance after

      const creditInsert = queries.find(
        (q) => q.sql.includes("INSERT INTO wallet_transactions") && q.sql.includes("cashback_credit"),
      );
      expect(creditInsert).toBeDefined();
      expect(creditInsert.params).toContain(200); // amount
      expect(creditInsert.params).toContain(0);   // previous balance
      expect(creditInsert.params).toContain(200); // balance after
    });

    it("does not award cashback when banner is not one of the 3 eligible banners", async () => {
      const queries = [];
      database.calculatePrice = vi.fn().mockResolvedValue({
        estimatedPrice: 66000,
        area: 30,
        areaUnit: "ft",
        label: "Estimated Total",
        notice: "",
      });

      mockQuery.mockImplementation(async (sql) => {
        if (sql.includes("FROM customers")) {
          return { rows: [{ id: 10, user_id: 1, name: "Test User", mobile: "9876543210" }] };
        }
        if (sql.includes("FROM products")) {
          return { rows: [{ pricing_method: "sqft", rate: 2200 }] };
        }
        if (sql.includes("FROM pricing_rules")) {
          return { rows: [] };
        }
        if (sql.includes("INSERT INTO audit_logs")) return { rows: [] };
        return { rows: [] };
      });

      mockClientQuery.mockImplementation(async (sql, params) => {
        queries.push({ sql, params });
        if (sql === "BEGIN" || sql === "COMMIT") return { rows: [] };
        if (sql.includes("INSERT IGNORE INTO customer_wallets")) return { rows: [] };
        if (sql.includes("SELECT id,balance,total_cashback_earned FROM customer_wallets")) {
          return { rows: [{ id: 99, balance: "0.00", total_cashback_earned: "0.00" }] };
        }
        if (sql.includes("INSERT INTO orders")) return { insertId: 78 };
        if (sql.includes("SELECT created_at FROM orders")) return { rows: [{ created_at: new Date() }] };
        if (sql.includes("INSERT INTO order_status_history")) return { rows: [] };
        if (sql.includes("INSERT INTO audit_logs")) return { rows: [] };
        return { rows: [] };
      });

      const orderData = {
        product: "Acrylic LED Sign",
        length: 10,
        width: 3,
        quantity: 1,
        estimatedPrice: 66000,
        useWallet: false,
        promotionBannerId: "non_eligible_banner_xyz", // Not eligible!
      };

      const result = await database.createOrder(
        { id: 1, role: "customer" },
        orderData,
        "ORD-2026-INELIGIBLE",
      );

      expect(result.cashbackEarned).toBe(0);
      expect(result.cashbackStatus).toBe("not_eligible");

      const creditInsert = queries.find(
        (q) => q.sql.includes("INSERT INTO wallet_transactions") && q.params?.includes("cashback_credit"),
      );
      expect(creditInsert).toBeUndefined();
    });
  });

  describe("reverseOrderWalletTransactions", () => {
    it("safely refunds wallet debit and reverses cashback when order is cancelled", async () => {
      const queries = [];
      const clientMock = {
        query: vi.fn().mockImplementation(async (sql, params) => {
          queries.push({ sql, params });
          if (sql.includes("SELECT wallet_id,transaction_type,amount FROM wallet_transactions")) {
            return {
              rows: [
                { wallet_id: 99, transaction_type: "wallet_debit", amount: "100.00" },
                { wallet_id: 99, transaction_type: "cashback_credit", amount: "200.00" },
              ],
            };
          }
          if (sql.includes("SELECT idempotency_key FROM wallet_transactions WHERE idempotency_key")) {
            return { rows: [] };
          }
          if (sql.includes("SELECT balance,total_cashback_earned FROM customer_wallets")) {
            return { rows: [{ balance: "200.00", total_cashback_earned: "200.00" }] };
          }
          if (sql.includes("INSERT INTO wallet_transactions")) return { rows: [] };
          if (sql.includes("UPDATE customer_wallets")) return { rows: [] };
          if (sql.includes("UPDATE wallet_transactions")) return { rows: [] };
          if (sql.includes("UPDATE orders")) return { rows: [] };
          return { rows: [] };
        }),
      };

      await database.reverseOrderWalletTransactions(clientMock, 88, 10);

      const refundEntry = queries.find(
        (q) => q.sql.includes("INSERT INTO wallet_transactions") && q.params?.includes("cancel-wallet-refund:88"),
      );
      expect(refundEntry).toBeDefined();

      const cashbackReversal = queries.find(
        (q) => q.sql.includes("INSERT INTO wallet_transactions") && q.params?.includes("cancel-cashback-reversal:88"),
      );
      expect(cashbackReversal).toBeDefined();

      const walletUpdate = queries.find((q) => q.sql.includes("UPDATE customer_wallets SET balance="));
      expect(walletUpdate).toBeDefined();

      const statusUpdate = queries.find(
        (q) => q.sql.includes("UPDATE wallet_transactions SET status='reversed'"),
      );
      expect(statusUpdate).toBeDefined();
    });
  });
});
