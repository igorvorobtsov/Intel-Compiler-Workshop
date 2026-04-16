program bounds
    implicit none
    integer :: arr(5)
    integer :: i

    arr = [1, 2, 3, 4, 5]

    ! Out of bounds access - should trigger runtime error with -check bounds
    print *, "Array element 6:", arr(6)

    ! Loop with bounds violation
    do i = 1, 10
        arr(i) = i * 10
    end do

    print *, "Sum:", sum(arr)
end program bounds
