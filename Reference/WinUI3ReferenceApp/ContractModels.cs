namespace WinUI3ReferenceApp;

public sealed class ContractRoot
{
    public int ContractVersion { get; set; }
    public List<ContractPage> Pages { get; set; } = new();
}

public sealed class ContractPage
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public List<ContractSection> Sections { get; set; } = new();
}

public sealed class ContractSection
{
    public string Id { get; set; } = "";
    public string Title { get; set; } = "";
    public List<ContractFixture> Fixtures { get; set; } = new();
}

public sealed class ContractFixture
{
    public string Id { get; set; } = "";
    public string Kind { get; set; } = "";
    public string Title { get; set; } = "";
}

