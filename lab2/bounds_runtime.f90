program bounds_runtime
    implicit none
    integer :: arr(5)
    integer :: i, idx

    arr = [1, 2, 3, 4, 5]

    ! Runtime bounds violation - read index from variable
    idx = 6
    print *, "Array element at index", idx, ":", arr(idx)

end program bounds_runtime
