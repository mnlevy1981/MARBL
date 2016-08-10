module marbl_get_put_drv

  use marbl_kinds_mod,     only : r8, char_len
  use marbl_constants_mod, only : c1, p5
  use marbl_logging,       only : marbl_log_type

  Implicit None
  Private
  Save

  integer, parameter :: km = 5

  Public :: test

Contains

  !*****************************************************************************

  subroutine test(marbl_instance, marbl_status_log)

    use marbl_interface,  only : marbl_interface_class
    use marbl_config_mod, only : marbl_config_set_defaults
    use marbl_parms,      only : marbl_parms_set_defaults

    type(marbl_interface_class), intent(inout) :: marbl_instance
    type(marbl_log_type),        intent(inout) :: marbl_status_log

    character(*), parameter      :: subname = 'marbl_get_put_drv:test'
    real(kind=r8), dimension(km) :: dz, zw, zt
    integer                      :: k

    ! Initialize levels
    dz = c1
    zw(1) = dz(1)
    zt(1) = p5*dz(1)
    do k=2,km
      zw(k) = zw(k-1) + dz(k)
      zt(k) = p5*(zw(k-1)+zw(k))
    end do

    ! Call marbl%config
    call marbl_instance%config(lgcm_has_global_ops = .true.)
    if (marbl_instance%StatusLog%labort_marbl) then
      call marbl_instance%StatusLog%log_error_trace('marbl%config', subname)
      return
    end if

    ! Set all config vars to -1 or .true.
    call set_all_vals(marbl_instance%configuration, marbl_status_log)
    if (marbl_status_log%labort_marbl) then
      call marbl_status_log%log_error_trace('set_all_vals', subname)
      return
    end if

    ! One by one, make sure vars are -1 or .true. and then set to n or .false.
    call check_all_vals(marbl_instance%configuration, marbl_status_log)
    if (marbl_status_log%labort_marbl) then
      call marbl_status_log%log_error_trace('check_all_vals', subname)
      return
    end if

    ! Reset to default values + ciso_on (needed to ensure tracer count consistency)
    call marbl_config_set_defaults()
    call marbl_instance%configuration%put('ciso_on', .true., marbl_status_log)
    if (marbl_status_log%labort_marbl) then
      call marbl_status_log%log_error_trace('configuration%put(ciso_on)', subname)
      return
    end if

    ! Call marbl%init
    call marbl_instance%init(gcm_num_levels = km,                             &
                             gcm_num_PAR_subcols = 1,                         &
                             gcm_num_elements_interior_forcing = 1,           &
                             gcm_num_elements_surface_forcing = 1,            &
                             gcm_dz = dz,                                     &
                             gcm_zw = zw,                                     &
                             gcm_zt = zt)
    if (marbl_instance%StatusLog%labort_marbl) then
      call marbl_instance%StatusLog%log_error_trace('marbl%init', subname)
      return
    end if

    ! Set all parameters to -1 or .true.
    call set_all_vals(marbl_instance%parameters, marbl_status_log)
    if (marbl_status_log%labort_marbl) then
      call marbl_status_log%log_error_trace('set_all_vals', subname)
      return
    end if

    ! One by one, make sure parms are -1 or .true. and then set to n or .false.
    call check_all_vals(marbl_instance%parameters, marbl_status_log)
    if (marbl_status_log%labort_marbl) then
      call marbl_status_log%log_error_trace('check_all_vals', subname)
      return
    end if

    ! Reset to default values + ciso_on (needed to ensure tracer count consistency)
    call marbl_parms_set_defaults(km)

    call marbl_instance%complete_config_and_init
    if (marbl_instance%StatusLog%labort_marbl) then
      call marbl_instance%StatusLog%log_error_trace(                          &
           'marbl%complete_config_and_init', subname)
      return
    end if

  end subroutine test

  !*****************************************************************************

  subroutine set_all_vals(config_or_parms, marbl_status_log)

    use marbl_config_mod, only : marbl_config_and_parms_type

    type(marbl_config_and_parms_type), intent(inout) :: config_or_parms
    type(marbl_log_type),              intent(inout) :: marbl_status_log

    character(*), parameter :: subname = 'marbl_get_put_drv:set_all_vals'
    character(len=char_len) :: log_message, sname, datatype
    integer :: n

    ! Put values into marbl_instance%configuration%vars(n)
    ! logicals = .true.
    ! integers = -1
    ! reals    = real(-1,r8)
    ! strings  = '-1'
    log_message = "Setting variables to .true. or -1 ..."
    call marbl_status_log%log_noerror(log_message, subname)
    do n=1,config_or_parms%cnt
      call config_or_parms%inquire_metadata(n, marbl_status_log,              &
                                            sname=sname, datatype=datatype)
      if (marbl_status_log%labort_marbl) then
        call marbl_status_log%log_error_trace('inquire_metadata', subname)
        return
      end if
      select case (trim(datatype))
        case ('real')
          call config_or_parms%put(sname, -1, marbl_status_log)
        case ('integer')
          call config_or_parms%put(sname, -1, marbl_status_log)
        case ('string')
          call config_or_parms%put(sname, '-1', marbl_status_log)
        case ('logical')
          call config_or_parms%put(sname, .true., marbl_status_log)
      end select
    end do
    log_message = "... Done!"
    call marbl_status_log%log_noerror(log_message, subname)

  end subroutine set_all_vals

  !*****************************************************************************

  subroutine check_all_vals(config_or_parms, marbl_status_log)

    use marbl_config_mod, only : marbl_config_and_parms_type

    type(marbl_config_and_parms_type), intent(inout) :: config_or_parms
    type(marbl_log_type),              intent(inout) :: marbl_status_log

    character(*), parameter :: subname = 'marbl_get_put_drv:check_all_vals'
    character(len=char_len) :: log_message, sname, datatype, sval
    logical  :: lval
    real(r8) :: rval
    integer  :: ival
    integer  :: n

    write(log_message, "(2A)") "Making sure variables are .true. or -1 then", &
                               " setting to .false. or n ..."
    call marbl_status_log%log_noerror(log_message, subname)
    do n=1,config_or_parms%cnt
      call config_or_parms%inquire_metadata(n, marbl_status_log,              &
                                            sname=sname, datatype=datatype)
      if (marbl_status_log%labort_marbl) then
        call marbl_status_log%log_error_trace('inquire_metadata', subname)
        return
      end if
      select case (trim(datatype))
        case ('real')
          ! (1) Check to see that variable was set to -1 correctly
          call config_or_parms%get(sname, rval, marbl_status_log)
          if (rval.ne.real(-1,r8)) then
            write(log_message, "(2A,E24.16,A)") trim(sname), ' = ', rval, ' not -1'
            call marbl_status_log%log_error(log_message, subname)
            return
          end if
          ! (2) Change value
          call config_or_parms%put(sname, n, marbl_status_log)
        case ('integer')
          ! (1) Check to see that variable was set to -1 correctly
          call config_or_parms%get(sname, ival, marbl_status_log)
          if (ival.ne.-1) then
            write(log_message, "(2A,I0,A)") trim(sname), ' = ', ival, ' not -1'
            call marbl_status_log%log_error(log_message, subname)
            return
          end if
          ! (2) Change value
          call config_or_parms%put(sname, n, marbl_status_log)
        case ('string')
          ! (1) Check to see that variable was set to .true. correctly
          call config_or_parms%get(sname, sval, marbl_status_log)
          if (trim(sval).ne.'-1') then
            write(log_message, "(4A)") trim(sname), ' = ', trim(sval), ', not -1'
            call marbl_status_log%log_error(log_message, subname)
            return
          end if
          ! (2) Change value
          write(sval, "(I0)") n
          call config_or_parms%put(sname, sval, marbl_status_log)
        case ('logical')
          ! (1) Check to see that variable was set to .true. correctly
          call config_or_parms%get(sname, lval, marbl_status_log)
          if (.not.lval) then
            write(log_message, "(2A)") trim(sname), ' is .false., not .true.'
            call marbl_status_log%log_error(log_message, subname)
            return
          end if
          ! (2) Change value
          call config_or_parms%put(sname, .false., marbl_status_log)
      end select
    end do
    log_message = "... Done!"
    call marbl_status_log%log_noerror(log_message, subname)

  end subroutine check_all_vals

  !*****************************************************************************

end module marbl_get_put_drv