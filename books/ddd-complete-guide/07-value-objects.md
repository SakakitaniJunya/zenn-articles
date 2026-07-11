---
title: "第7章: Value Object — 値に意味を持たせる"
---


## Value Objectの本質

「5000円」という金額を考えてみてください。あなたの財布に入っている5000円札と、私の財布に入っている5000円札は、同じ価値を持ちますか？もちろん「はい」です。どちらの5000円札を使っても同じものが買えます。紙幣の固体番号が違っても、価値は同じです。

一方、あなたと私は「同じ人」でしょうか？名前が同じ人間が存在しても、それは別人です。人間はIDや名前ではなく、「その人自身」としての同一性（Identity）を持ちます。

この2つの違いが、DDDにおける**Value Object（値オブジェクト）**と**Entity（エンティティ）**の根本的な違いです。Value Objectは「値そのものが意味を持つ」——同じ値であれば同じものとして扱います。

## 3つの特性

Value Objectは次の3つの特性を持ちます。

### 1. 不変性（Immutability）

Value Objectは作成後に変更できません。「5000円」を「6000円」に変更するのではなく、「6000円という新しいValue Object」を作成します。これにより、Value Objectは副作用を持たない安全なオブジェクトになります。

### 2. 等値性（Structural Equality）

Value Objectの同一性はIDではなく「値」で決まります。`new Money(5000, "JPY")`と`new Money(5000, "JPY")`は、異なるインスタンスであっても**等しい**と判定されます。

### 3. 自己検証（Self-Validation）

Value Objectは生成時に自分自身の整合性を検証します。「-100円」や「abc@」のような不正な値は、Value Objectのコンストラクタで弾かれます。不正な状態のValue Objectは存在できません。

## アンチパターン: Primitive Obsession（プリミティブ執着）

### Before: プリミティブ型の乱用

```csharp
// Before: プリミティブ型に頼った設計（Primitive Obsession）
public class Order
{
    // これらは全部「どんな値でもOK」なため、バグが混入しやすい
    public decimal Amount { get; set; }          // 負の値も入れられる
    public string Currency { get; set; }          // "USD"も"XXX"も"円"も入れられる
    public string CustomerEmail { get; set; }     // "not-an-email"でも通る
    public string CustomerPhone { get; set; }     // "abcde"でも通る

    public void ApplyDiscount(decimal discountRate)
    {
        // discountRateが1.5でも-0.5でもコンパイルエラーにならない
        Amount = Amount * (1 - discountRate);
    }
}

// 呼び出し側でどんなバグも混入できる
var order = new Order
{
    Amount = -5000,          // 負の金額
    Currency = "日本円",      // 不正なコード
    CustomerEmail = "test",  // メールアドレスではない
};
order.ApplyDiscount(1.5m);  // 割引率150%の異常値
```

この設計では、型システムがビジネスルールを何も守ってくれません。すべての検証をサービス層に書かなければならず、それでも検証漏れが発生します。

### After: Value Objectを使った設計

```csharp
// After: Value Objectを使った設計（型が業務ルールを表現する）
public class Order
{
    public Money TotalPrice { get; }
    public EmailAddress CustomerEmail { get; }
    public PhoneNumber CustomerPhone { get; }

    public Order(Money totalPrice, EmailAddress customerEmail, PhoneNumber customerPhone)
    {
        // Value Objectが不正な値を持っている時点で存在できないため、
        // ここに来た時点でこれらは常に正しい値を持つ
        TotalPrice = totalPrice;
        CustomerEmail = customerEmail;
        CustomerPhone = customerPhone;
    }

    public Order ApplyDiscount(DiscountRate rate)
    {
        // DiscountRate自体が0〜1の範囲のみ許容するため、異常値は入らない
        return new Order(TotalPrice.Multiply(1 - rate.Value), CustomerEmail, CustomerPhone);
    }
}
```

## Value Object基底クラスの設計

C#でValue Objectを実装する際の基底クラスです。

```csharp
// Value Object基底クラス: 等値性をGetEqualityComponentsで定義
public abstract class ValueObject
{
    protected abstract IEnumerable<object?> GetEqualityComponents();

    public override bool Equals(object? obj)
    {
        if (obj is null || obj.GetType() != GetType()) return false;
        var other = (ValueObject)obj;
        return GetEqualityComponents().SequenceEqual(other.GetEqualityComponents());
    }

    public override int GetHashCode() =>
        GetEqualityComponents()
            .Select(x => x?.GetHashCode() ?? 0)
            .Aggregate((x, y) => x ^ y);

    public static bool operator ==(ValueObject? left, ValueObject? right) =>
        left?.Equals(right) ?? right is null;

    public static bool operator !=(ValueObject? left, ValueObject? right) =>
        !(left == right);
}
```

## Moneyクラスの完全実装

金融ドメインで最もよく使われるValue Object、`Money`クラスを実装します。

```csharp
public sealed class Money : ValueObject
{
    public decimal Value { get; }
    public Currency Currency { get; }

    private Money(decimal value, Currency currency)
    {
        if (value < 0)
            throw new DomainException($"金額に負の値は使用できません: {value}");
        Value = value;
        Currency = currency;
    }

    public static Money Of(decimal value, Currency currency) =>
        new Money(value, currency);

    public static Money Yen(decimal value) => Of(value, Currency.JPY);
    public static Money Usd(decimal value) => Of(value, Currency.USD);

    // 算術演算（同一通貨のみ許可）
    public Money Add(Money other)
    {
        EnsureSameCurrency(other);
        return new Money(Value + other.Value, Currency);
    }

    public Money Subtract(Money other)
    {
        EnsureSameCurrency(other);
        var result = Value - other.Value;
        if (result < 0)
            throw new DomainException("差し引き後に負の金額になります");
        return new Money(result, Currency);
    }

    public Money Multiply(decimal factor)
    {
        if (factor < 0)
            throw new DomainException("乗数に負の値は使用できません");
        return new Money(Math.Round(Value * factor, 0, MidpointRounding.AwayFromZero), Currency);
    }

    // フォーマット
    public override string ToString() =>
        Currency.Code switch
        {
            "JPY" => $"¥{Value:N0}",
            "USD" => $"${Value:N2}",
            _ => $"{Value} {Currency.Code}"
        };

    private void EnsureSameCurrency(Money other)
    {
        if (Currency != other.Currency)
            throw new DomainException($"通貨が一致しません: {Currency.Code} と {other.Currency.Code}");
    }

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
        yield return Currency;
    }
}

// 使用例
var price = Money.Yen(3000);
var tax = price.Multiply(0.10m);           // ¥300
var total = price.Add(tax);               // ¥3,300
Console.WriteLine(total);                 // "¥3,300"

// 等値性テスト
var a = Money.Yen(5000);
var b = Money.Yen(5000);
Console.WriteLine(a == b);               // True（同じ値なので等しい）

// 通貨違いはエラー
var usd = Money.Usd(50);
// a.Add(usd); // DomainException: 通貨が一致しません
```

## EmailAddressのValue Object実装

```csharp
public sealed class EmailAddress : ValueObject
{
    private static readonly Regex EmailRegex =
        new(@"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
            RegexOptions.Compiled);

    public string Value { get; }

    private EmailAddress(string value) => Value = value;

    public static EmailAddress Of(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new DomainException("メールアドレスを空にすることはできません");

        var normalized = value.Trim().ToLowerInvariant();

        if (!EmailRegex.IsMatch(normalized))
            throw new DomainException($"無効なメールアドレス形式です: {value}");

        return new EmailAddress(normalized);
    }

    // ドメイン部を取得する便利メソッド
    public string Domain => Value.Split('@')[1];

    public override string ToString() => Value;

    protected override IEnumerable<object?> GetEqualityComponents()
    {
        yield return Value;
    }
}

// 使用例
var email = EmailAddress.Of("User@Example.COM"); // 正規化されて "user@example.com"
// EmailAddress.Of("not-an-email"); // DomainException
// EmailAddress.Of("");             // DomainException
```

## Value Objectを使うべきよくある実例

| プリミティブ | Value Object | 守られるルール |
|---|---|---|
| `decimal price` | `Money` | 負の値禁止・通貨混在禁止 |
| `string email` | `EmailAddress` | フォーマット検証・正規化 |
| `string phone` | `PhoneNumber` | 国際形式・桁数検証 |
| `(DateTime start, DateTime end)` | `DateRange` | start < end の保証 |
| `(double lat, double lon)` | `Coordinate` | 緯度経度の範囲検証 |
| `decimal rate` | `DiscountRate` | 0〜1の範囲限定 |

> **専門家の視点**
>
> 「なぜ`int`や`string`じゃダメなのか？」という問いに対する最も実用的な答えは「**コンパイラを仲間にできるから**」です。`string email`と`string phone`はどちらも`string`なので、コンパイラは誤って渡しても検出できません。しかし`EmailAddress`と`PhoneNumber`は別の型なので、引数を取り違えた瞬間にコンパイルエラーになります。
>
> Greg Young（Event Sourcingの提唱者）はかつて「型は最もコストの低いユニットテストである」と述べました。Value Objectを使うことは、実行時に発見されるバグをコンパイル時に発見することを意味します。プロダクションで起きた¥-5000のバグより、コンパイルエラーのほうがはるかに低コストで解決できます。
