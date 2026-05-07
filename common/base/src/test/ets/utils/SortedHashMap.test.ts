import { SortedHashMap, IComparable } from '../../../../main/ets/utils/SortedHashMap';

class MockValue implements IComparable<MockValue> {
  id: number;
  constructor(id: number) {
    this.id = id;
  }
  compareTo(other: MockValue): number {
    return this.id - other.id;
  }
}

describe('SortedHashMap', () => {
  let sortedMap: SortedHashMap<string, MockValue>;

  beforeEach(() => {
    sortedMap = new SortedHashMap<string, MockValue>();
  });

  describe('delete', () => {
    it('should return -1 when deleting from an empty map', () => {
      const index = sortedMap.delete('non-existent');
      expect(index).toBe(-1);
    });

    it('should return -1 when deleting a non-existent key', () => {
      sortedMap.set('a', new MockValue(1));
      const index = sortedMap.delete('b');
      expect(index).toBe(-1);
      expect(sortedMap.length()).toBe(1);
    });

    it('should delete an existing key and return its index (descending order)', () => {
      // Insertion order: 10, 20, 30, 40 -> Sorted order (descending): 40, 30, 20, 10
      sortedMap.set('k10', new MockValue(10));
      sortedMap.set('k20', new MockValue(20));
      sortedMap.set('k30', new MockValue(30));
      sortedMap.set('k40', new MockValue(40));

      // [40, 30, 20, 10]
      // index of k30 (30) is 1.
      // index of k10 (10) is 3.

      const index30 = sortedMap.delete('k30');
      expect(index30).toBe(1);
      expect(sortedMap.length()).toBe(3);

      const index10 = sortedMap.delete('k10');
      expect(index10).toBe(2); // After removing 30, 10 is at index 2
      expect(sortedMap.length()).toBe(2);

      const values = sortedMap.getSortedValues();
      expect(values[0].id).toBe(40);
      expect(values[1].id).toBe(20);
    });

    it('should maintain sorted order after multiple deletes', () => {
      sortedMap.set('a', new MockValue(10));
      sortedMap.set('b', new MockValue(20));
      sortedMap.set('c', new MockValue(30));
      sortedMap.set('d', new MockValue(40));
      // [40, 30, 20, 10]

      sortedMap.delete('b'); // deletes 20 at index 2
      // [40, 30, 10]

      let values = sortedMap.getSortedValues();
      expect(values[0].id).toBe(40);
      expect(values[1].id).toBe(30);
      expect(values[2].id).toBe(10);

      sortedMap.delete('d'); // deletes 40 at index 0
      // [30, 10]
      values = sortedMap.getSortedValues();
      expect(values[0].id).toBe(30);
      expect(values[1].id).toBe(10);
    });

    it('should correctly handle deleting the last element', () => {
      sortedMap.set('a', new MockValue(10));
      const index = sortedMap.delete('a');
      expect(index).toBe(0);
      expect(sortedMap.length()).toBe(0);
      expect(sortedMap.getSortedValues().length).toBe(0);
    });
  });
});
