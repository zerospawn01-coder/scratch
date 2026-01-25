from topological_auditor import TopologicalAuditor

def test_auditor_pipeline():
    print("Testing: Topological Auditor Pipeline")
    auditor = TopologicalAuditor(n_strands=6)
    
    # 1. Standard Case
    print("\n[Test 1] Consistent Information")
    auditor.mock_llm_call("Query 1", "Fact A is true.")
    assert auditor.audit_log[-1]['alert'] == "STABLE"
    
    # 2. Inconsistent RAG
    print("\n[Test 2] Direct Controversy")
    # This should trigger a drift/inflation as it attempts to rewire the braid
    auditor.mock_llm_call("Query 2", "Fact A is false and actually Fact B.")
    
    report = auditor.generate_sanity_report()
    print(f"Generated Report:\n{report}")
    
    assert auditor.audit_log[-1]['alert'] in ["INFO", "WARN", "CRITICAL"]
    print("\nDay 4 Auditor Pipeline Verified.")

if __name__ == "__main__":
    test_auditor_pipeline()
